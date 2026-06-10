import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'auth_service.dart';

class TimelineService {
  static const String _storageKey = 'emotion_timeline';
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient();

  // ─────────────────────────────────────────────────────────
  // SAVE — always write locally so just-analysed items appear instantly
  // ─────────────────────────────────────────────────────────

  Future<void> saveResult(EmotionResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _readLocal(prefs);

    final filtered = current.where((item) {
      if (result.clientId != null &&
          item.clientId != null &&
          item.clientId == result.clientId) {
        return false;
      }

      if (result.analysisId != null &&
          item.analysisId != null &&
          item.analysisId == result.analysisId) {
        return false;
      }

      final sameFingerprint =
          item.type == result.type &&
              item.emotion == result.emotion &&
              item.timestamp.difference(result.timestamp).inSeconds.abs() < 2;

      return !sameFingerprint;
    }).toList();

    filtered.insert(0, result);
    await _writeLocal(prefs, filtered.take(100).toList());
    refreshNotifier.value++;
  }

  // ─────────────────────────────────────────────────────────
  // GET HISTORY — API-only when logged in
  // ─────────────────────────────────────────────────────────

  Future<List<EmotionResult>> getHistory() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (!isLoggedIn) {
      // Guest mode: use local cache
      final prefs = await SharedPreferences.getInstance();
      final local = _readLocal(prefs);
      local.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return local;
    }

    try {
      final List<EmotionResult> allHistory = [];
      int page = 1;
      const int limit = 100; // request 100 at a time
      bool hasMore = true;

      while (hasMore) {
        final response = await _api.get(
          '/analysis/history',
          queryParams: {
            'page': page.toString(),
            'pageSize': limit.toString(),
          },
        );

        if (!response.isSuccess) {
          debugPrint('⚠️ Remote history failed at page $page (${response.statusCode})');
          break;
        }

        final rawItems = _extractHistoryItems(response.body);
        if (rawItems.isEmpty) {
          hasMore = false;
          break;
        }

        final pageHistory = rawItems
            .map(EmotionResult.fromHistoryItem)
            .where((e) => e.type != 'unknown')
            .toList();

        allHistory.addAll(pageHistory);

        // Deduce page size to check if we are on the last page.
        // Fallback default is 10.
        int pageSize = 10;
        if (response.body is Map<String, dynamic>) {
          final bodyMap = response.body as Map<String, dynamic>;
          if (bodyMap['page_size'] != null) {
            pageSize = (bodyMap['page_size'] as num).toInt();
          } else if (bodyMap['pageSize'] != null) {
            pageSize = (bodyMap['pageSize'] as num).toInt();
          } else if (bodyMap['limit'] != null) {
            pageSize = (bodyMap['limit'] as num).toInt();
          }
        }

        // If we fetched fewer items than the page size or limit, we've hit the end of the history.
        // Safety limit is page 20 to prevent infinite loops.
        if (rawItems.length < pageSize || rawItems.length < limit || page >= 20) {
          hasMore = false;
        } else {
          page++;
        }
      }

      allHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      debugPrint('✅ Fetched ${allHistory.length} items from API (across pages)');
      return allHistory;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Timeline history fetch failed: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────
  // EMOTION COUNTS / STREAK
  // ─────────────────────────────────────────────────────────

  Future<Map<String, int>> getEmotionCounts({
    List<EmotionResult>? cachedHistory,
  }) async {
    final history = cachedHistory ?? await getHistory();
    final counts = <String, int>{};

    for (final item in history) {
      final key = item.emotion.trim().toLowerCase();
      if (key.isEmpty || key == 'neutral') continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return counts;
  }

  Future<int> getStreak({
    List<EmotionResult>? cachedHistory,
  }) async {
    final history = cachedHistory ?? await getHistory();
    if (history.isEmpty) return 0;

    final dates = history
        .map((e) => DateTime(
            e.cairoTimestamp.year, e.cairoTimestamp.month, e.cairoTimestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (!dates.contains(todayDate) && !dates.contains(yesterdayDate)) {
      return 0;
    }

    DateTime expected = dates.first;
    for (final date in dates) {
      if (date.isAtSameMomentAs(expected)) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // ─────────────────────────────────────────────────────────
  // DELETE SINGLE — local + API synchronised
  // ─────────────────────────────────────────────────────────

  Future<bool> deleteAnalysis(EmotionResult result) async {
    final isLoggedIn = await _authService.isLoggedIn();

    // 1. Always delete from local storage if it exists there
    try {
      final prefs = await SharedPreferences.getInstance();
      final local = _readLocal(prefs);
      final initialLength = local.length;
      local.removeWhere((item) {
        if (result.analysisId != null && item.analysisId == result.analysisId) {
          return true;
        }
        if (result.clientId != null && item.clientId == result.clientId) {
          return true;
        }
        return false;
      });

      if (local.length != initialLength) {
        await _writeLocal(prefs, local);
      }
    } catch (e) {
      debugPrint('⚠️ Local delete failed: $e');
    }

    // 2. If logged in, also delete from API (using database integer analysisId)
    if (isLoggedIn) {
      final id = result.analysisId;
      if (id == null) {
        debugPrint('⚠️ Logged in but no analysisId to delete from API');
        refreshNotifier.value++;
        return true; // Return true as it is removed locally
      }

      try {
        final response = await _api.delete('/analysis/$id');
        if (response.isSuccess) {
          debugPrint('🗑️ Deleted analysis $id from API');
          refreshNotifier.value++;
          return true;
        } else {
          debugPrint('⚠️ API delete failed: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        debugPrint('⚠️ Remote delete failed: $e');
        return false;
      }
    } else {
      // Guest mode - local deletion is sufficient
      debugPrint('🗑️ Deleted analysis ${result.clientId} locally (guest mode)');
      refreshNotifier.value++;
      return true;
    }
  }

  // ─────────────────────────────────────────────────────────
  // CLEAR ALL — local + API synchronised
  // ─────────────────────────────────────────────────────────

  Future<bool> clearAllHistory() async {
    final isLoggedIn = await _authService.isLoggedIn();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('⚠️ Local clear failed: $e');
    }

    if (isLoggedIn) {
      try {
        final response = await _api.delete('/analysis/clear');
        if (response.isSuccess) {
          debugPrint('🧹 All history cleared from API');
          refreshNotifier.value++;
          return true;
        } else {
          debugPrint('⚠️ API clear failed: ${response.statusCode}');
          return false;
        }
      } catch (e) {
        debugPrint('⚠️ Remote clear failed: $e');
        return false;
      }
    } else {
      // Guest mode - local clear is sufficient
      debugPrint('🧹 Cleared history locally (guest mode)');
      refreshNotifier.value++;
      return true;
    }
  }

  Future<bool> clearCloudHistory() async => clearAllHistory();

  Future<void> syncHistory() async {
    refreshNotifier.value++;
  }

  // ─────────────────────────────────────────────────────────
  // LOCAL STORAGE HELPERS (guest mode / save-on-analyse)
  // ─────────────────────────────────────────────────────────

  List<EmotionResult> _readLocal(SharedPreferences prefs) {
    final rawList = prefs.getStringList(_storageKey) ?? [];

    return rawList.map((item) {
      try {
        final json = jsonDecode(item) as Map<String, dynamic>;
        return EmotionResult.fromJson(
          json,
          (json['type'] ?? 'unknown').toString(),
        );
      } catch (e) {
        debugPrint('⚠️ Local history parse error: $e');
        return EmotionResult.empty();
      }
    }).toList()
      ..removeWhere((e) => e.type == 'unknown' && e.confidence == 0.0);
  }

  Future<void> _writeLocal(
    SharedPreferences prefs,
    List<EmotionResult> items,
  ) async {
    final encoded = items.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  List<Map<String, dynamic>> _extractHistoryItems(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (data is Map<String, dynamic> && data['items'] is List) {
        return (data['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (body['items'] is List) {
        return (body['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return const [];
  }
}
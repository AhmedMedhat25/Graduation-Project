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

  Future<List<EmotionResult>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final localHistory = _readLocal(prefs);

    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      localHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return localHistory;
    }

    try {
      final response = await _api.get(
        '/analysis/history',
        queryParams: {'page': '1', 'limit': '50'},
      );

      if (!response.isSuccess) {
        debugPrint('⚠️ Remote history failed. Using ${localHistory.length} local items.');
        localHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return localHistory;
      }

      final remoteItems = _extractHistoryItems(response.body);
      final remoteHistory = remoteItems
          .map(EmotionResult.fromHistoryItem)
          .where((e) => e.type != 'unknown')
          .toList();

      debugPrint('🔄 Merging ${remoteHistory.length} remote and ${localHistory.length} local items...');

      final merged = _mergeHistory(remoteHistory, localHistory);
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Ensure we don't accidentally save 0 items if something goes wrong
      if (merged.isNotEmpty || localHistory.isEmpty) {
        await _writeLocal(prefs, merged.take(100).toList());
      }
      
      debugPrint('🔄 Final history count: ${merged.length}');
      return merged;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('⚠️ Timeline history fetch failed: $e');
      localHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return localHistory;
    }
  }

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
        .map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    // Use Cairo time (UTC+3) to ensure streak doesn't break based on device timezone
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

  Future<bool> deleteAnalysis(EmotionResult result) async {
    if (result.deleteKey == null) {
      debugPrint('⚠️ Cannot delete item: No valid key');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final local = _readLocal(prefs);

    local.removeWhere((item) {
      if (item.clientId != null && item.clientId == result.clientId) return true;
      if (item.analysisId != null && item.analysisId == result.analysisId) return true;
      return item.timestamp.isAtSameMomentAs(result.timestamp) &&
          item.emotion == result.emotion;
    });

    await _writeLocal(prefs, local);
    refreshNotifier.value++;

    try {
      final response = await _api.delete('/analysis/${result.deleteKey}');
      return response.isSuccess;
    } catch (e) {
      debugPrint('⚠️ Remote delete failed: $e');
      return false;
    }
  }

  Future<bool> clearAllHistory() async {
    try {
      await _api.delete('/analysis/clear');
    } catch (e) {
      debugPrint('⚠️ Remote clear failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    refreshNotifier.value++;
    return true;
  }

  Future<bool> clearCloudHistory() async {
    return clearAllHistory();
  }

  Future<void> syncHistory() async {
    await getHistory();
    refreshNotifier.value++;
  }

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
      return body.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (data is Map<String, dynamic> && data['items'] is List) {
        return (data['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (body['items'] is List) {
        return (body['items'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return const [];
  }

  List<EmotionResult> _mergeHistory(
      List<EmotionResult> remote,
      List<EmotionResult> local,
      ) {
    // Start with all local items. We prefer local because they have full detailed data
    // right after an analysis, whereas remote might be missing fields or still processing.
    final merged = <EmotionResult>[...local];

    for (final remoteItem in remote) {
      final localMatchIndex = merged.indexWhere((localItem) {
        if (localItem.clientId != null &&
            remoteItem.clientId != null &&
            localItem.clientId == remoteItem.clientId) {
          return true;
        }

        if (localItem.analysisId != null &&
            remoteItem.analysisId != null &&
            localItem.analysisId == remoteItem.analysisId) {
          return true;
        }

        return localItem.type == remoteItem.type &&
            localItem.emotion == remoteItem.emotion &&
            localItem.timestamp.difference(remoteItem.timestamp).inSeconds.abs() < 5;
      });

      if (localMatchIndex == -1) {
        // Not in local, so add it
        merged.add(remoteItem);
      } else {
        // It exists in local. Let's see if remote has MORE data.
        final localItem = merged[localMatchIndex];
        
        // If local is neutral 0.0 but remote has real data, replace local with remote
        if (localItem.confidence == 0.0 && remoteItem.confidence > 0.0) {
          merged[localMatchIndex] = remoteItem;
        }
        // If remote has a real analysisId but local doesn't, copy it over so we can delete it later
        else if (localItem.analysisId == null && remoteItem.analysisId != null) {
          merged[localMatchIndex] = EmotionResult(
            emotion: localItem.emotion,
            confidence: localItem.confidence,
            allEmotions: localItem.allEmotions,
            timestamp: localItem.timestamp,
            type: localItem.type,
            analysisId: remoteItem.analysisId, // Update ID
            clientId: localItem.clientId,
            timeline: localItem.timeline,
          );
        }
      }
    }

    return merged;
  }
}
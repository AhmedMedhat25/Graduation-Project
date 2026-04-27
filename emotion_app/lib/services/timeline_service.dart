import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emotion_result.dart';
import './auth_service.dart';
import './api_client.dart';

class TimelineService {
  static const String _storageKey = 'emotion_timeline';
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  final _authService = AuthService();
  final _api = ApiClient();

  // ================= SAVE =================

  Future<void> saveResult(EmotionResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _readLocal(prefs);

    existing.insert(0, result);

    final trimmed = existing.take(100).toList();
    final encoded = trimmed.map((r) => jsonEncode(r.toJson())).toList();

    await prefs.setStringList(_storageKey, encoded);
    refreshNotifier.value++;
  }

  // ================= READ LOCAL =================

  List<EmotionResult> _readLocal(SharedPreferences prefs) {
    final stored = prefs.getStringList(_storageKey) ?? [];

    return stored.map((s) {
      try {
        final json = jsonDecode(s) as Map<String, dynamic>;

        final timelineList = json['timeline'] as List? ?? [];

        List<Map<String, dynamic>>? parsedTimeline;

        if (timelineList.isNotEmpty) {
          parsedTimeline = timelineList
              .whereType<Map<String, dynamic>>() // 🔥 FIX
              .toList();
        }

        return EmotionResult(
          emotion: (json['emotion'] ?? 'neutral').toString().toLowerCase(),
          confidence: (json['confidence'] as num? ?? 0).toDouble(),
          allEmotions: Map<String, double>.from(
            (json['allEmotions'] as Map? ?? {}).map(
                  (k, v) =>
                  MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
            ),
          ),
          timestamp: DateTime.tryParse(json['timestamp'] ?? '') ??
              DateTime.now(),
          type: json['type'] ?? 'unknown',
          analysisId: json['analysisId'] as int?,
          clientId: json['clientId']?.toString(), // 🔥 restore UUID
          timeline: parsedTimeline,
        );
      } catch (e) {
        debugPrint('Error parsing local item: $e');
        return EmotionResult.empty(); // 🔥 IMPORTANT FIX
      }
    }).toList();
  }

  // ================= GET HISTORY =================

  Future<List<EmotionResult>> getHistory() async {
    final isLoggedIn = await _authService.isLoggedIn();

    if (isLoggedIn) {
      try {
        final response =
        await _api.get('/analysis/history', queryParams: {
          'page': '1',
          'limit': '50',
        });

        if (response.isSuccess && response.body != null) {
          final body = response.body;

          List items = [];

          if (body is List) {
            items = body;
          } else if (body is Map) {
            final data = body['data'];

            if (data is Map && data['items'] is List) {
              items = data['items'];
            } else if (data is List) {
              items = data;
            } else if (body['items'] is List) {
              items = body['items'];
            }
          }

          final cloudHistory = items
              .whereType<Map<String, dynamic>>() // 🔥 FIX
              .map((item) => EmotionResult.fromHistoryItem(item))
              .toList();

          final prefs = await SharedPreferences.getInstance();
          final localHistory = _readLocal(prefs);

          // 🔥 FIX: better duplicate detection
          final localPreserved = localHistory.where((localItem) {
            if (localItem.analysisId != null) {
              return !cloudHistory.any(
                      (c) => c.analysisId == localItem.analysisId);
            }

            final duplicate = cloudHistory.any((c) =>
            c.type == localItem.type &&
                (c.timestamp
                    .difference(localItem.timestamp)
                    .inSeconds
                    .abs() <
                    3)); // tighter window

            return !duplicate;
          }).toList();

          final combined = [...cloudHistory, ...localPreserved];

          combined.sort((a, b) => b.timestamp.compareTo(a.timestamp));

          await _syncToLocal(combined);

          return combined;
        }
      } on SessionExpiredException {
        debugPrint('Session expired');
      } catch (e) {
        debugPrint('Timeline error: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    return _readLocal(prefs);
  }

  // ================= DELETE =================

  Future<bool> deleteAnalysis(EmotionResult result) async {
    bool canProceed = true;

    // 🔥 FIX: API DELETE endpoint is /analysis/{clientId} (UUID string),
    // not /analysis/{analysisId} (integer). Use deleteKey helper.
    final key = result.deleteKey;

    if (key != null) {
      try {
        final response = await _api.delete('/analysis/$key');

        if (!response.isSuccess && response.statusCode != 404) {
          canProceed = false;
        }
      } catch (e) {
        debugPrint('Delete error: $e');
        canProceed = false;
      }
    }

    if (!canProceed) return false;

    final prefs = await SharedPreferences.getInstance();
    final history = _readLocal(prefs);

    final targetTime = result.timestamp.toIso8601String();

    history.removeWhere((r) =>
    (r.deleteKey != null &&
        result.deleteKey != null &&
        r.deleteKey == result.deleteKey) ||
        (r.timestamp.toIso8601String() == targetTime &&
            r.type == result.type));

    await _syncToLocal(history);
    refreshNotifier.value++;

    return true;
  }

  // ================= STATS =================

  Future<Map<String, dynamic>?> getAnalysisStats() async {
    try {
      final response = await _api.get('/analysis/stats');

      if (response.isSuccess && response.body is Map) {
        return response.body as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Stats error: $e');
    }
    return null;
  }

  // ================= UTIL =================

  Future<void> _syncToLocal(List<EmotionResult> history) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = history.map((r) => jsonEncode(r.toJson())).toList();

    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    refreshNotifier.value++;
  }

  Future<bool> clearCloudHistory() async {
    try {
      // 🔥 FIX: correct endpoint is /analysis/clear, not /analysis/all
      final response = await _api.delete('/analysis/clear');
      if (response.isSuccess) {
        await clearHistory();
        return true;
      }
    } catch (e) {
      debugPrint('Clear cloud history error: $e');
    }
    return false;
  }

  Future<Map<String, int>> getEmotionCounts(
      {List<EmotionResult>? cachedHistory}) async {
    final history = cachedHistory ?? await getHistory();

    final counts = <String, int>{};

    for (final r in history) {
      counts[r.emotion] = (counts[r.emotion] ?? 0) + 1;
    }

    return counts;
  }

  Future<List<EmotionResult>> getFilteredHistory(String type) async {
    final history = await getHistory();

    if (type == 'all') return history;

    return history.where((r) => r.type == type).toList();
  }

  // ================= STREAK =================

  Future<int> getStreak({List<EmotionResult>? cachedHistory}) async {
    final history = cachedHistory ?? await getHistory();

    if (history.isEmpty) return 0;

    final uniqueDays = history.map((r) {
      return DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
    }).toSet().toList();

    uniqueDays.sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (uniqueDays.first != today && uniqueDays.first != yesterday) {
      return 0;
    }

    int streak = 1;
    DateTime current = uniqueDays.first;

    for (int i = 1; i < uniqueDays.length; i++) {
      final expected = current.subtract(const Duration(days: 1));

      if (uniqueDays[i] == expected) {
        streak++;
        current = expected;
      } else {
        break;
      }
    }

    return streak;
  }
}
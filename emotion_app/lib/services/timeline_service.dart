import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emotion_result.dart';
import './auth_service.dart';
import './api_client.dart';

// ============================================================
//  📊  TIMELINE SERVICE  –  Cloud-first + Local fallback
// ============================================================
class TimelineService {
  static const String _storageKey = 'emotion_timeline';
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);

  final _authService = AuthService();
  final _api = ApiClient();

  // ── Save result locally (does NOT hit the network) ────────
  Future<void> saveResult(EmotionResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = _readLocal(prefs);
    existing.insert(0, result);

    // Keep last 100 entries
    final trimmed = existing.take(100).toList();
    final encoded = trimmed.map((r) => jsonEncode(r.toJson())).toList();

    await prefs.setStringList(_storageKey, encoded);
    refreshNotifier.value++;
  }

  // ── Read from local prefs only ────────────────────────────
  List<EmotionResult> _readLocal(SharedPreferences prefs) {
    final stored = prefs.getStringList(_storageKey) ?? [];
    return stored.map((s) {
      final json = jsonDecode(s) as Map<String, dynamic>;
      
      final timelineList = json['timeline'] as List? ?? [];
      List<Map<String, dynamic>>? parsedTimeline;
      if (timelineList.isNotEmpty) {
        parsedTimeline = timelineList.map((e) => e as Map<String, dynamic>).toList();
      }
      
      return EmotionResult(
        emotion: json['emotion'] ?? 'neutral',
        confidence: (json['confidence'] as num? ?? 0).toDouble(),
        allEmotions: Map<String, double>.from(
          (json['allEmotions'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        ),
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        type: json['type'] ?? 'unknown',
        analysisId: json['analysisId'] as int?,
        timeline: parsedTimeline,
      );
    }).toList();
  }

  // ── Get history: Cloud-first, local fallback ──────────────
  Future<List<EmotionResult>> getHistory() async {
    // 1. Try fetching from Cloud if logged in
    final token = await _authService.getToken();
    if (token != null) {
      try {
        final response = await _api.get('/v2/analysis/history', queryParams: {
          'page': '1',
          'limit': '50',
        });

        if (response.isSuccess) {
          final body = response.body;
          // Handle both paginated {items:[]} and raw list [] responses
          final List items = body is List ? body : (body['items'] ?? body['data'] ?? []);

          if (items.isNotEmpty) {
            final cloudHistory = items.map<EmotionResult>((item) {
              return EmotionResult.fromHistoryItem(item as Map<String, dynamic>);
            }).toList();

            // Merge with local-only items (like Photo and Video, or offline analyses)
            final prefs = await SharedPreferences.getInstance();
            final localHistory = _readLocal(prefs);
            
            // Filter local items that are NOT in the cloud history (matching by time within 5s)
            final localOnly = localHistory.where((localItem) {
              return !cloudHistory.any((cloudItem) => 
                  cloudItem.timestamp.difference(localItem.timestamp).inSeconds.abs() < 5);
            }).toList();

            final combinedHistory = [...cloudHistory, ...localOnly];
            combinedHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            await _syncToLocal(combinedHistory);
            return combinedHistory;
          }
        }
      } on SessionExpiredException {
        debugPrint('Session expired during timeline fetch');
      } catch (e) {
        // Fallback to local on network/timeout error
        debugPrint('Timeline sync error: $e');
      }
    }

    // 2. Fallback to Local Storage
    final prefs = await SharedPreferences.getInstance();
    return _readLocal(prefs);
  }

  // ── Get analysis stats from cloud ─────────────────────────
  Future<Map<String, dynamic>?> getAnalysisStats() async {
    try {
      final response = await _api.get('/v2/analysis/stats');
      if (response.isSuccess && response.body is Map) {
        return response.body as Map<String, dynamic>;
      }
    } on SessionExpiredException {
      debugPrint('Session expired during stats fetch');
    } catch (e) {
      debugPrint('Stats fetch error: $e');
    }
    return null;
  }

  // ── Delete a specific analysis ────────────────────────────
  Future<bool> deleteAnalysis(int id) async {
    try {
      final response = await _api.delete('/v2/analysis/$id');
      return response.isSuccess;
    } catch (e) {
      debugPrint('Delete analysis error: $e');
      return false;
    }
  }

  // ── Clear all analysis history ────────────────────────────
  Future<bool> clearCloudHistory() async {
    try {
      final response = await _api.delete('/v2/analysis/clear');
      if (response.isSuccess) {
        await clearHistory();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Clear cloud history error: $e');
      return false;
    }
  }

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

  Future<Map<String, int>> getEmotionCounts({List<EmotionResult>? cachedHistory}) async {
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

  // ── Calculate Day Streak ──────────────────────────────────
  Future<int> getStreak({List<EmotionResult>? cachedHistory}) async {
    final history = cachedHistory ?? await getHistory();
    if (history.isEmpty) return 0;

    // Get unique days (ignoring time) where user did an analysis
    final uniqueDays = history.map((r) {
      return DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
    }).toSet().toList();
    
    uniqueDays.sort((a, b) => b.compareTo(a)); // Descending

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // If the most recent analysis isn't today or yesterday, streak is broken
    if (uniqueDays.first != today && uniqueDays.first != yesterday) {
      return 0;
    }

    int streak = 1;
    DateTime currentDate = uniqueDays.first;

    for (int i = 1; i < uniqueDays.length; i++) {
      final prevDate = currentDate.subtract(const Duration(days: 1));
      if (uniqueDays[i] == prevDate) {
        streak++;
        currentDate = prevDate;
      } else {
        break; // Streak broken
      }
    }

    return streak;
  }
}

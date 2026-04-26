import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';

// ════════════════════════════════════════════════════════════
//  ALERTS SERVICE  –  Cloud-first with local fallback
// ════════════════════════════════════════════════════════════
class EmotionAlert {
  final String id;
  final String title;
  final String message;
  final String emotion;
  final String type; // warning, info, positive
  final DateTime timestamp;
  bool isRead;
  final String? severity;   // from cloud: low, medium, high, critical
  final bool? resolved;     // from cloud

  EmotionAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.emotion,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.severity,
    this.resolved,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'emotion': emotion,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        if (severity != null) 'severity': severity,
        if (resolved != null) 'resolved': resolved,
      };

  factory EmotionAlert.fromJson(Map<String, dynamic> j) => EmotionAlert(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? '',
        message: j['message'] ?? '',
        emotion: j['emotion'] ?? '',
        type: j['type'] ?? 'info',
        timestamp: DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
        isRead: j['isRead'] ?? j['is_read'] ?? false,
        severity: j['severity'],
        resolved: j['resolved'],
      );

  /// Parse a cloud alert from the API
  factory EmotionAlert.fromCloudJson(Map<String, dynamic> j) => EmotionAlert(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Alert',
        message: j['message'] ?? j['description'] ?? '',
        emotion: j['emotion'] ?? j['dominant_emotion'] ?? '',
        type: _mapSeverityToType(j['severity']),
        timestamp: DateTime.tryParse(j['triggered_at'] ?? j['timestamp'] ?? '') ?? DateTime.now(),
        isRead: j['resolved'] == true,
        severity: j['severity'],
        resolved: j['resolved'],
      );

  static String _mapSeverityToType(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical':
      case 'high':
        return 'warning';
      case 'medium':
        return 'info';
      case 'low':
        return 'positive';
      default:
        return 'info';
    }
  }
}

class AlertsService {
  static const String _key = 'emotion_alerts';
  final _api = ApiClient();

  // ── Generate alert from a new emotion result ─────────────
  Future<EmotionAlert?> generateAlert(EmotionResult result) async {
    final alert = _buildAlert(result);
    if (alert != null) {
      await _saveAlert(alert);
    }
    return alert;
  }

  EmotionAlert? _buildAlert(EmotionResult result) {
    final e = result.emotion.toLowerCase();
    final conf = result.confidence;
    final id =
        '${result.timestamp.millisecondsSinceEpoch}_${result.type}';

    // High-confidence negative emotions → warning
    if (e == 'angry' && conf > 0.55) {
      return EmotionAlert(
        id: id,
        title: '😠 High Anger Detected',
        message:
            'A strong anger signal (${(conf * 100).toInt()}%) was detected in your ${result.type} analysis. Consider taking a short break or breathing exercise.',
        emotion: e,
        type: 'warning',
        timestamp: result.timestamp,
      );
    }
    if (e == 'sad' && conf > 0.55) {
      return EmotionAlert(
        id: id,
        title: '😢 Sadness Noticed',
        message:
            'Sadness was detected (${(conf * 100).toInt()}%) in your ${result.type}. Reaching out to someone you trust can help.',
        emotion: e,
        type: 'warning',
        timestamp: result.timestamp,
      );
    }
    if (e == 'fearful' && conf > 0.5) {
      return EmotionAlert(
        id: id,
        title: '😨 Fear Signal Detected',
        message:
            'A fear signal (${(conf * 100).toInt()}%) was found in your ${result.type}. Grounding techniques may help calm your nervous system.',
        emotion: e,
        type: 'warning',
        timestamp: result.timestamp,
      );
    }
    if (e == 'disgusted' && conf > 0.55) {
      return EmotionAlert(
        id: id,
        title: '🤢 Disgust Detected',
        message:
            'Disgust (${(conf * 100).toInt()}%) was found in your ${result.type} input. Reflecting on what triggered it may be helpful.',
        emotion: e,
        type: 'warning',
        timestamp: result.timestamp,
      );
    }

    // Positive emotions → positive alert
    if (e == 'happy' && conf > 0.65) {
      return EmotionAlert(
        id: id,
        title: '😊 Great Mood Detected!',
        message:
            'Strong happiness (${(conf * 100).toInt()}%) was found in your ${result.type}. Keep that positive energy going!',
        emotion: e,
        type: 'positive',
        timestamp: result.timestamp,
      );
    }

    // Neutral info alerts for surprised / neutral with high confidence
    if (e == 'surprised' && conf > 0.6) {
      return EmotionAlert(
        id: id,
        title: '😲 Surprise Moment',
        message:
            'You seem quite surprised (${(conf * 100).toInt()}%) in your ${result.type} analysis.',
        emotion: e,
        type: 'info',
        timestamp: result.timestamp,
      );
    }

    return null; // no alert for low-confidence or neutral
  }

  // ── Streak alert: 3+ same negative emotion in a row ──────
  Future<EmotionAlert?> checkStreak(List<EmotionResult> history) async {
    if (history.length < 3) return null;
    final last3 = history.take(3).toList();
    final negatives = {'angry', 'sad', 'fearful', 'disgusted'};

    if (last3.every((r) => r.emotion == last3.first.emotion) &&
        negatives.contains(last3.first.emotion)) {
      final e = last3.first.emotion;
      final alert = EmotionAlert(
        id: 'streak_${DateTime.now().millisecondsSinceEpoch}',
        title: '⚠️ Repeated ${_capitalize(e)} Detected',
        message:
            'Your last 3 analyses all show $e. This pattern may indicate sustained stress. Consider speaking to someone.',
        emotion: e,
        type: 'warning',
        timestamp: DateTime.now(),
      );
      await _saveAlert(alert);
      return alert;
    }
    return null;
  }

  // ── CRUD — Cloud-first with local fallback ───────────────
  Future<List<EmotionAlert>> getAlerts() async {
    // Try cloud first
    try {
      final response = await _api.get('/alerts', queryParams: {
        'page': '1',
        'pageSize': '50',
      });

      if (response.isSuccess) {
        final body = response.body;
        final List items = body is List
            ? body
            : (body['items'] ?? body['data'] ?? []);

        if (items.isNotEmpty) {
          final cloudAlerts = items
              .map((j) => EmotionAlert.fromCloudJson(j as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          // Cache cloud alerts locally
          await _cacheAlerts(cloudAlerts);
          return cloudAlerts;
        }
      }
    } on SessionExpiredException {
      debugPrint('Session expired during alerts fetch');
    } catch (e) {
      debugPrint('Cloud alerts fetch error: $e');
    }

    // Fallback to local
    return _getLocalAlerts();
  }

  /// Get alert stats from the cloud
  Future<Map<String, dynamic>?> getAlertStats() async {
    try {
      final response = await _api.get('/alerts/stats');
      if (response.isSuccess && response.body is Map) {
        return response.body as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Alert stats error: $e');
    }
    return null;
  }

  /// Resolve an alert on the cloud
  Future<bool> resolveAlert(String id) async {
    try {
      final response = await _api.patch('/alerts/$id/resolve');
      if (response.isSuccess) {
        await markRead(id);
        return true;
      }
    } catch (e) {
      debugPrint('Resolve alert error: $e');
    }
    // Still mark read locally even if cloud fails
    await markRead(id);
    return false;
  }

  /// Delete an alert on the cloud
  Future<bool> deleteCloudAlert(String id) async {
    try {
      final response = await _api.delete('/alerts/$id');
      if (response.isSuccess) {
        // Remove from local cache too
        await _removeLocalAlert(id);
        return true;
      }
    } catch (e) {
      debugPrint('Delete alert error: $e');
    }
    return false;
  }

  Future<List<EmotionAlert>> _getLocalAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    return stored
        .map((s) => EmotionAlert.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<int> getUnreadCount() async {
    final alerts = await getAlerts();
    return alerts.where((a) => !a.isRead).length;
  }

  Future<void> markAllRead() async {
    final alerts = await _getLocalAlerts();
    for (final a in alerts) {
      a.isRead = true;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, alerts.map((a) => jsonEncode(a.toJson())).toList());
  }

  Future<void> markRead(String id) async {
    final alerts = await _getLocalAlerts();
    final idx = alerts.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      alerts[idx].isRead = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, alerts.map((a) => jsonEncode(a.toJson())).toList());
    }
  }

  Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _saveAlert(EmotionAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];
    stored.insert(0, jsonEncode(alert.toJson()));
    // Keep last 50 alerts
    await prefs.setStringList(_key, stored.take(50).toList());
  }

  Future<void> _cacheAlerts(List<EmotionAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = alerts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_key, encoded.take(50).toList());
  }

  Future<void> _removeLocalAlert(String id) async {
    final alerts = await _getLocalAlerts();
    alerts.removeWhere((a) => a.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, alerts.map((a) => jsonEncode(a.toJson())).toList());
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';

// ════════════════════════════════════════════════════════════
// ALERT MODEL
// ════════════════════════════════════════════════════════════

class EmotionAlert {
  final String id;
  final String title;
  final String message;
  final String emotion;
  final String type;
  final DateTime timestamp;
  bool isRead;
  final String? severity;
  final bool? resolved;
  final String? recommendedAction;

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
    this.recommendedAction,
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
    if (recommendedAction != null)
      'recommendedAction': recommendedAction,
  };

  factory EmotionAlert.fromJson(Map<String, dynamic> j) => EmotionAlert(
    id: j['id']?.toString() ?? '',
    title: j['title'] ?? '',
    message: j['message'] ?? '',
    emotion: (j['emotion'] ?? '').toString().toLowerCase(),
    type: j['type'] ?? 'info',
    timestamp:
    DateTime.tryParse(j['timestamp'] ?? '') ?? DateTime.now(),
    isRead: j['isRead'] ?? j['is_read'] ?? false,
    severity: j['severity']?.toString(),
    resolved: j['resolved'],
    recommendedAction:
    j['recommendedAction'] ?? j['recommended_action'],
  );

  factory EmotionAlert.fromCloudJson(Map<String, dynamic> j) =>
      EmotionAlert(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? 'Alert',
        message: j['message'] ?? j['description'] ?? '',
        emotion: (j['emotion'] ?? j['dominant_emotion'] ?? '')
            .toString()
            .toLowerCase(),
        type: _mapSeverityToType(j['severity']),
        timestamp: DateTime.tryParse(
            j['triggered_at'] ?? j['timestamp'] ?? '') ??
            DateTime.now(),
        isRead: j['resolved'] == true,
        severity: j['severity']?.toString(),
        resolved: j['resolved'],
        recommendedAction:
        j['recommended_action'] ?? j['recommendedAction'],
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

// ════════════════════════════════════════════════════════════
// ALERTS SERVICE
// ════════════════════════════════════════════════════════════

class AlertsService {
  static const String _key = 'emotion_alerts';
  final _api = ApiClient();

  // ================= GENERATE ALERT =================

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

    if (e == 'angry' && conf > 0.55) {
      return EmotionAlert(
        id: id,
        title: '😠 High Anger Detected',
        message:
        'Strong anger (${(conf * 100).toInt()}%) detected.',
        emotion: e,
        type: 'warning',
        timestamp: result.timestamp,
      );
    }

    if (e == 'sad' && conf > 0.55) {
      return EmotionAlert(
        id: id,
        title: '😢 Sadness Detected',
        message:
        'Sadness (${(conf * 100).toInt()}%) detected.',
        emotion: e,
        type: 'warning',
        timestamp: result.timestamp,
      );
    }

    if (e == 'happy' && conf > 0.65) {
      return EmotionAlert(
        id: id,
        title: '😊 Great Mood!',
        message:
        'Happiness (${(conf * 100).toInt()}%) detected.',
        emotion: e,
        type: 'positive',
        timestamp: result.timestamp,
      );
    }

    return null;
  }

  // ================= STREAK =================

  Future<EmotionAlert?> checkStreak(
      List<EmotionResult> history) async {
    if (history.length < 3) return null;

    final latest3 = history.reversed.take(3).toList();

    final negatives = {'angry', 'sad', 'fearful', 'disgusted'};

    if (latest3.every((r) => r.emotion == latest3.first.emotion) &&
        negatives.contains(latest3.first.emotion)) {
      final e = latest3.first.emotion;

      final alert = EmotionAlert(
        id: 'streak_${DateTime.now().millisecondsSinceEpoch}',
        title: '⚠️ Repeated ${_capitalize(e)}',
        message: '3 consecutive $e detected.',
        emotion: e,
        type: 'warning',
        timestamp: DateTime.now(),
      );

      await _saveAlert(alert);
      return alert;
    }

    return null;
  }

  // ================= GET ALERTS =================

  Future<List<EmotionAlert>> getAlerts() async {
    try {
      final response = await _api.get('/alerts');

      if (response.isSuccess && response.body != null) {
        final body = response.body;

        List items = [];

        if (body is List) {
          items = body;
        } else if (body is Map) {
          if (body['data'] is List) {
            items = body['data'];
          } else if (body['items'] is List) {
            items = body['items'];
          }
        }

        final alerts = items
            .whereType<Map<String, dynamic>>()
            .map((j) => EmotionAlert.fromCloudJson(j))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (alerts.isNotEmpty) {
          await _cacheAlerts(alerts);
        }

        return alerts;
      }
    } on SessionExpiredException {
      debugPrint('Session expired');
    } catch (e) {
      debugPrint('Error: $e');
    }

    return _getLocalAlerts();
  }

  // ================= LOCAL STORAGE =================

  Future<List<EmotionAlert>> _getLocalAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];

    return stored
        .map((s) => EmotionAlert.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> _saveAlert(EmotionAlert alert) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_key) ?? [];

    stored.insert(0, jsonEncode(alert.toJson()));

    await prefs.setStringList(_key, stored.take(50).toList());
  }

  Future<void> _cacheAlerts(List<EmotionAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();

    final encoded =
    alerts.map((a) => jsonEncode(a.toJson())).toList();

    await prefs.setStringList(_key, encoded.take(50).toList());
  }

  Future<void> markRead(String id) async {
    final alerts = await _getLocalAlerts();

    for (var a in alerts) {
      if (a.id == id) a.isRead = true;
    }

    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
        _key, alerts.map((a) => jsonEncode(a.toJson())).toList());
  }

  Future<void> markAllRead() async {
    final alerts = await _getLocalAlerts();
    for (var a in alerts) {
      a.isRead = true;
    }
    await _cacheAlerts(alerts);
  }

  Future<int> getUnreadCount() async {
    final alerts = await _getLocalAlerts();
    return alerts.where((a) => !a.isRead).length;
  }

  Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
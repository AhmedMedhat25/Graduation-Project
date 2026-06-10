import 'package:flutter/foundation.dart';
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
  final int? analysisId;
  final String? clientId;

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
    this.analysisId,
    this.clientId,
  });

  /// Parse a cloud alert from the REST API response.
  factory EmotionAlert.fromCloudJson(Map<String, dynamic> j) {
    final severity = (j['severity'] ?? 'medium').toString().toLowerCase();
    final message = (j['message'] ?? j['description'] ?? '').toString();
    final emotion = _extractEmotionFromMessage(message);
    final title = _buildTitleFromSeverityAndEmotion(severity, emotion, message);

    return EmotionAlert(
      id: j['id']?.toString() ?? '',
      title: title,
      message: message,
      emotion: emotion,
      type: _mapSeverityToType(severity),
      timestamp: EmotionResult.parseCairoTime(
          j['triggered_at'] ?? j['timestamp']),
      isRead: j['resolved'] == true,
      severity: severity,
      resolved: j['resolved'],
      recommendedAction:
      j['recommended_action'] ?? j['recommendedAction'],
      analysisId: j['analysis_id'] is int ? j['analysis_id'] : null,
      clientId: j['client_id']?.toString(),
    );
  }

  /// Extract the dominant emotion from a cloud alert message.
  static String _extractEmotionFromMessage(String message) {
    final lower = message.toLowerCase();

    const emotions = {
      'anger': 'anger',
      'angry': 'anger',
      'sadness': 'sadness',
      'sad': 'sadness',
      'fear': 'fear',
      'fearful': 'fear',
      'disgust': 'disgust',
      'disgusted': 'disgust',
      'joy': 'joy',
      'happy': 'joy',
      'happiness': 'joy',
      'surprise': 'surprise',
      'surprised': 'surprise',
      'neutral': 'neutral',
    };

    for (final entry in emotions.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }

    if (lower.contains('negative')) return 'sadness';
    if (lower.contains('positive')) return 'joy';

    return '';
  }

  /// Build a human-friendly title from severity + emotion context.
  static String _buildTitleFromSeverityAndEmotion(
      String severity, String emotion, String message,
      ) {
    if (emotion.isNotEmpty) {
      final emoji = _emotionEmoji(emotion);
      final label = emotion[0].toUpperCase() + emotion.substring(1);

      switch (severity) {
        case 'critical':
          return '$emoji Critical: $label Alert';
        case 'high':
          return '$emoji High $label Detected';
        case 'medium':
          return '$emoji $label Detected';
        case 'low':
          return '$emoji Mild $label Noted';
        default:
          return '$emoji $label Alert';
      }
    }

    switch (severity) {
      case 'critical':
        return '🚨 Critical Emotion Alert';
      case 'high':
        return '⚠️ High Emotion Alert';
      case 'medium':
        return '📊 Emotion Alert';
      case 'low':
        return '📝 Emotion Note';
      default:
        return '🔔 Alert';
    }
  }

  static String _emotionEmoji(String emotion) {
    switch (emotion) {
      case 'anger': return '😠';
      case 'sadness': return '😢';
      case 'fear': return '😨';
      case 'disgust': return '🤢';
      case 'joy': return '😊';
      case 'surprise': return '😲';
      case 'neutral': return '😐';
      default: return '🔔';
    }
  }

  static String _mapSeverityToType(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'critical': return 'critical';
      case 'high': return 'warning';
      case 'medium': return 'info';
      case 'low': return 'positive';
      default: return 'info';
    }
  }
}

// ════════════════════════════════════════════════════════════
// ALERT STATS MODEL
// ════════════════════════════════════════════════════════════

class AlertStats {
  final int totalAlerts;
  final int unreadAlerts;
  final int criticalAlerts;
  final int highAlerts;

  const AlertStats({
    this.totalAlerts = 0,
    this.unreadAlerts = 0,
    this.criticalAlerts = 0,
    this.highAlerts = 0,
  });

  factory AlertStats.fromJson(Map<String, dynamic> j) => AlertStats(
    totalAlerts: _safeInt(j['total_alerts']),
    unreadAlerts: _safeInt(j['unread_alerts']),
    criticalAlerts: _safeInt(j['critical_alerts']),
    highAlerts: _safeInt(j['high_alerts']),
  );

  static int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

// ════════════════════════════════════════════════════════════
// ALERTS SERVICE (Cloud Only)
// ════════════════════════════════════════════════════════════

class AlertsService {
  final _api = ApiClient();

  // ================= GET ALERTS (Cloud Only) =================

  Future<List<EmotionAlert>> getAlerts() async {
    try {
      final response = await _api.get('/alerts');

      if (response.isSuccess && response.body != null) {
        final body = response.body;

        debugPrint('🔔 ALERTS RAW RESPONSE keys: ${body is Map ? body.keys.toList() : body.runtimeType}');

        List items = [];

        if (body is List) {
          items = body;
        } else if (body is Map) {
          final data = body['data'];

          if (data is Map && data['items'] is List) {
            items = data['items'] as List;
          } else if (data is List) {
            items = data;
          } else if (body['items'] is List) {
            items = body['items'] as List;
          }
        }

        final remoteAlerts = items
            .whereType<Map>()
            .map((j) => EmotionAlert.fromCloudJson(Map<String, dynamic>.from(j)))
            .toList();

        // Sort descending by timestamp
        remoteAlerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return remoteAlerts;
      }
    } on SessionExpiredException {
      debugPrint('Session expired');
    } catch (e) {
      debugPrint('❌ Alerts fetch error: $e');
    }

    return [];
  }

  // ================= GET ALERT STATS =================

  Future<AlertStats?> getStats() async {
    try {
      final response = await _api.get('/alerts/stats');

      if (response.isSuccess && response.body is Map) {
        final body = response.body as Map;
        final data = body['data'];

        if (data is Map) {
          return AlertStats.fromJson(Map<String, dynamic>.from(data));
        }
      }
    } catch (e) {
      debugPrint('❌ Alert stats error: $e');
    }

    return null;
  }

  // ================= RESOLVE ALERT =================

  Future<bool> resolveAlert(String alertId) async {
    try {
      final response = await _api.patch('/alerts/$alertId/resolve');

      if (response.isSuccess) {
        debugPrint('✅ Alert $alertId resolved');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Resolve alert error: $e');
    }
    return false;
  }

  // ================= DELETE ALERT =================

  Future<bool> deleteAlert(String alertId) async {
    try {
      final response = await _api.delete('/alerts/$alertId');

      if (response.isSuccess) {
        debugPrint('✅ Alert $alertId deleted');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Delete alert error: $e');
    }
    return false;
  }

  // ================= UTILS =================

  Future<void> markRead(String id) async {
    // Forward directly to resolve API
    await resolveAlert(id);
  }

  Future<int> getUnreadCount() async {
    try {
      final stats = await getStats();
      if (stats != null) {
        return stats.unreadAlerts;
      }
    } catch (_) {}
    return 0;
  }
}
import 'package:flutter/foundation.dart';

class EmotionResult {
  final String emotion;
  final double confidence;
  final Map<String, double> allEmotions;
  final DateTime timestamp;
  final String type;
  final int? analysisId;
  final String? clientId; // UUID used by DELETE /api/analysis/{clientId}
  final List<Map<String, dynamic>>? timeline;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.allEmotions,
    required this.timestamp,
    required this.type,
    this.analysisId,
    this.clientId,
    this.timeline,
  });

  // ── Safe empty fallback ───────────────────────────────────
  factory EmotionResult.empty() => EmotionResult(
        emotion: 'neutral',
        confidence: 0.0,
        allEmotions: {'neutral': 0.0},
        timestamp: DateTime.now(),
        type: 'unknown',
      );

  /// Best identifier for DELETE /api/analysis/{clientId}
  String? get deleteKey => clientId ?? analysisId?.toString();

  // ================= BASIC PARSER =================

  factory EmotionResult.fromJson(Map<String, dynamic> json, String type) {
    return EmotionResult(
      emotion: (json['emotion'] ?? 'neutral').toString().toLowerCase(),
      confidence: _safeDouble(json['confidence']) ?? 0.0,
      allEmotions: Map<String, double>.from(
        (json['all_emotions'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), _safeDouble(v) ?? 0.0),
        ),
      ),
      timestamp: DateTime.now(),
      type: type,
    );
  }

  // ================= TEXT API =================

  factory EmotionResult.fromTextApiV2(Map<String, dynamic> rawJson) {
    try {
      // Unwrap nested `result` if present
      final json = rawJson['result'] is Map
          ? Map<String, dynamic>.from(rawJson['result'] as Map)
          : rawJson;

      final analysisId = _safeInt(rawJson['id']) ?? _safeInt(json['id']);
      final clientId =
          rawJson['client_id']?.toString() ?? json['client_id']?.toString();

      final allEmotions = <String, double>{};

      // Pull emotion probabilities — try multiple field names
      final probsRaw = json['combined_results'] ??
          json['combinedResults'] ??
          _nestedField(json, 'full_text_analysis', 'probabilities') ??
          json['probabilities'];

      _extractEmotions(probsRaw, allEmotions);

      // Dominant emotion — safe Map extraction (no `as` cast)
      final dominantRaw = json['combined_final_emotion'] ??
          json['combinedFinalEmotion'] ??
          _nestedField(json, 'full_text_analysis', 'dominant');

      final dominant =
          dominantRaw is Map ? Map<String, dynamic>.from(dominantRaw) : null;

      String label =
          (dominant?['label'] ?? dominant?['emotion'] ?? 'neutral')
              .toString()
              .toLowerCase();

      // Safe numeric extraction — handles int, double, and percent scale
      double conf = _safeDouble(dominant?['confidence']) ??
          _safeDouble(dominant?['confidence_percent']) ??
          0.0;
      if (conf > 1.0) conf /= 100.0; // normalise percent → fraction

      // Fallback: derive from allEmotions
      if (conf == 0.0 && allEmotions.isNotEmpty) {
        final max =
            allEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);
        label = max.key;
        conf = max.value;
        if (conf > 1.0) conf /= 100.0;
      }

      if (allEmotions.isEmpty) allEmotions[label] = conf;

      final timelineList =
          (json['timeline'] ?? json['sentences_analysis']) as List? ?? [];

      return EmotionResult(
        emotion: label,
        confidence: conf,
        allEmotions: allEmotions,
        timestamp: DateTime.tryParse(
                (json['timestamp'] ?? json['createdAt'])?.toString() ?? '') ??
            DateTime.now(),
        type: 'text',
        analysisId: analysisId,
        clientId: clientId,
        timeline: timelineList.whereType<Map<String, dynamic>>().toList()
            .let((l) => l.isNotEmpty ? l : null),
      );
    } catch (e, st) {
      debugPrint('⚠️ Text parsing error: $e\n$st');
      debugPrint('⚠️ Raw JSON: $rawJson');
      return EmotionResult.empty();
    }
  }

  // ================= AUDIO API =================

  factory EmotionResult.fromAudioApiV2(Map<String, dynamic> rawJson) {
    try {
      final json = rawJson['result'] is Map
          ? Map<String, dynamic>.from(rawJson['result'] as Map)
          : rawJson;

      final analysisId = _safeInt(rawJson['id']) ?? _safeInt(json['id']);
      final clientId =
          rawJson['client_id']?.toString() ?? json['client_id']?.toString();

      final allEmotions = <String, double>{};

      final combined = json['final_multimodal_results'] ??
          json['combined_results'] ??
          json['probabilities'];

      _extractEmotions(combined, allEmotions);

      // Dominant — multiple field names
      final dominantRaw = json['final_multimodal_emotion'] ??
          json['dominant'] ??
          json['combined_final_emotion'];

      final dominant =
          dominantRaw is Map ? Map<String, dynamic>.from(dominantRaw) : null;

      String label =
          (dominant?['label'] ?? dominant?['emotion'] ?? 'neutral')
              .toString()
              .toLowerCase();

      double conf = _safeDouble(dominant?['confidence']) ??
          _safeDouble(dominant?['confidence_percent']) ??
          0.0;
      if (conf > 1.0) conf /= 100.0;

      if (conf == 0.0 && allEmotions.isNotEmpty) {
        final max =
            allEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);
        label = max.key;
        conf = max.value;
        if (conf > 1.0) conf /= 100.0;
      }

      if (allEmotions.isEmpty) allEmotions[label] = conf;

      final timelineList =
          (json['timeline'] ?? json['segments']) as List? ?? [];

      return EmotionResult(
        emotion: label,
        confidence: conf,
        allEmotions: allEmotions,
        timestamp: DateTime.tryParse(
                (json['timestamp'] ?? json['createdAt'])?.toString() ?? '') ??
            DateTime.now(),
        type: 'audio',
        analysisId: analysisId,
        clientId: clientId,
        timeline: timelineList.whereType<Map<String, dynamic>>().toList()
            .let((l) => l.isNotEmpty ? l : null),
      );
    } catch (e, st) {
      debugPrint('⚠️ Audio parsing error: $e\n$st');
      debugPrint('⚠️ Raw JSON: $rawJson');
      return EmotionResult.empty();
    }
  }

  // ================= HISTORY =================

  factory EmotionResult.fromHistoryItem(Map<String, dynamic> item) {
    try {
      final data = item['result'] is Map
          ? Map<String, dynamic>.from(item['result'] as Map)
          : item;

      final type = item['type']?.toString().toLowerCase() ?? 'text';

      final fullData = <String, dynamic>{
        ...data,
        'id': item['id'],
        if (item['client_id'] != null) 'client_id': item['client_id'],
        'timestamp': item['triggered_at'] ??
            item['timestamp'] ??
            data['timestamp'],
      };

      return type == 'audio'
          ? EmotionResult.fromAudioApiV2(fullData)
          : EmotionResult.fromTextApiV2(fullData);
    } catch (e, st) {
      debugPrint('⚠️ History parse error: $e\n$st');
      return EmotionResult.empty();
    }
  }

  // ================= JSON =================

  Map<String, dynamic> toJson() => {
        'emotion': emotion,
        'confidence': confidence,
        'allEmotions': allEmotions,
        'timestamp': timestamp.toIso8601String(),
        'type': type,
        if (analysisId != null) 'analysisId': analysisId,
        if (clientId != null) 'clientId': clientId,
        if (timeline != null) 'timeline': timeline,
      };

  // ============================================================
  // PRIVATE SAFE-CAST HELPERS
  // ============================================================

  /// Safely converts any value to double — never throws.
  static double? _safeDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Safely converts any value to int — never throws.
  static int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Reads a nested field from a map without throwing.
  static dynamic _nestedField(Map json, String outer, String inner) {
    final o = json[outer];
    if (o is Map) return o[inner];
    return null;
  }

  /// Populates [out] from a List or Map of emotion values.
  /// Handles both `[{label, confidence}]` list and `{emotion: value}` map.
  static void _extractEmotions(dynamic raw, Map<String, double> out) {
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final label =
            (item['label'] ?? item['emotion'] ?? '').toString().toLowerCase();
        // item['score'] read safely — no `as` cast
        final conf = _safeDouble(item['confidence']) ??
            _safeDouble(item['score']) ??
            _safeDouble(item['confidence_percent']) ??
            0.0;
        if (label.isNotEmpty) {
          out[label] = conf > 1.0 ? conf / 100.0 : conf;
        }
      }
    } else if (raw is Map) {
      raw.forEach((k, v) {
        final conf = _safeDouble(v) ?? 0.0;
        out[k.toString().toLowerCase()] = conf > 1.0 ? conf / 100.0 : conf;
      });
    }
  }
}

// ============================================================
// LIST EXTENSION — .let() helper
// ============================================================

extension _LetExt<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ============================================================
// USER MODEL
// ============================================================

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['user_id'] ?? json['id'])?.toString() ?? '',
      name: json['full_name']?.toString() ??
          json['name']?.toString() ??
          'Unknown',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

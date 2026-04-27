import 'package:flutter/foundation.dart';
class EmotionResult {
  final String emotion;
  final double confidence;
  final Map<String, double> allEmotions;
  final DateTime timestamp;
  final String type;
  final int? analysisId;
  final List<Map<String, dynamic>>? timeline;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.allEmotions,
    required this.timestamp,
    required this.type,
    this.analysisId,
    this.timeline,
  });

  // 🔥 SAFE EMPTY (used in error cases)
  factory EmotionResult.empty() {
    return EmotionResult(
      emotion: 'neutral',
      confidence: 0.0,
      allEmotions: {'neutral': 0.0},
      timestamp: DateTime.now(),
      type: 'unknown',
    );
  }

  // ================= BASIC PARSER =================

  factory EmotionResult.fromJson(Map<String, dynamic> json, String type) {
    return EmotionResult(
      emotion: (json['emotion'] ?? 'neutral').toString().toLowerCase(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      allEmotions: Map<String, double>.from(
        (json['all_emotions'] as Map? ?? {}).map(
              (k, v) =>
              MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
        ),
      ),
      timestamp: DateTime.now(),
      type: type,
    );
  }

  // ================= TEXT API =================

  factory EmotionResult.fromTextApiV2(Map<String, dynamic> rawJson) {
    try {
      final json = rawJson['result'] is Map<String, dynamic>
          ? rawJson['result']
          : rawJson;

      final analysisId =
          rawJson['id'] as int? ?? json['id'] as int?;

      final allEmotions = <String, double>{};

      final probsRaw = json['combined_results'] ??
          json['combinedResults'] ??
          (json['full_text_analysis'] is Map
              ? (json['full_text_analysis'] as Map)['probabilities']
              : null) ??
          json['probabilities'];

      if (probsRaw is Map) {
        probsRaw.forEach((k, v) {
          if (v is num) {
            allEmotions[k.toString().toLowerCase()] = v.toDouble();
          }
        });
      } else if (probsRaw is List) {
        for (final item in probsRaw) {
          if (item is Map) {
            final l = (item['label'] ?? item['emotion'] ?? '')
                .toString()
                .toLowerCase();

            final c =
            (item['confidence'] ?? item['score'] as num? ?? 0.0)
                .toDouble();

            if (l.isNotEmpty) {
              allEmotions[l] = c;
            }
          }
        }
      }

      final dominant = (json['combined_final_emotion'] ??
          json['combinedFinalEmotion']) as Map?;

      String label = (dominant?['label'] ??
          dominant?['emotion'] ??
          'neutral')
          .toString()
          .toLowerCase();

      double conf =
          (dominant?['confidence'] as num?)?.toDouble() ?? 0.0;

      // 🔥 fallback to max probability
      if (conf == 0.0 && allEmotions.isNotEmpty) {
        final max = allEmotions.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        label = max.key;
        conf = max.value;
      }

      if (allEmotions.isEmpty) {
        allEmotions[label] = conf;
      }

      final timelineList =
          (json['timeline'] ?? json['sentences_analysis']) as List? ?? [];

      final parsedTimeline = timelineList
          .whereType<Map<String, dynamic>>() // 🔥 safe
          .toList();

      return EmotionResult(
        emotion: label,
        confidence: conf,
        allEmotions: allEmotions,
        timestamp: DateTime.tryParse(
            (json['timestamp'] ?? json['createdAt'])
                ?.toString() ??
                '') ??
            DateTime.now(),
        type: 'text',
        analysisId: analysisId,
        timeline:
        parsedTimeline.isNotEmpty ? parsedTimeline : null,
      );
    } catch (e) {
      debugPrint('Text parsing error: $e');
      return EmotionResult.empty();
    }
  }

  // ================= AUDIO API =================

  factory EmotionResult.fromAudioApiV2(Map<String, dynamic> rawJson) {
    try {
      final json = rawJson['result'] is Map<String, dynamic>
          ? rawJson['result']
          : rawJson;

      final analysisId =
          rawJson['id'] as int? ?? json['id'] as int?;

      final allEmotions = <String, double>{};

      final combined = json['final_multimodal_results'] ??
          json['probabilities'] ??
          json['combined_results'];

      if (combined is List) {
        for (final item in combined) {
          if (item is Map) {
            final l = (item['label'] ?? item['emotion'] ?? '')
                .toString()
                .toLowerCase();

            final c =
            (item['confidence'] ?? item['score'] as num? ?? 0.0)
                .toDouble();

            if (l.isNotEmpty) {
              allEmotions[l] = c;
            }
          }
        }
      } else if (combined is Map) {
        combined.forEach((k, v) {
          if (v is num) {
            allEmotions[k.toString().toLowerCase()] =
                v.toDouble();
          }
        });
      }

      final dominant = (json['final_multimodal_emotion'] ??
          json['dominant'] ??
          {}) as Map;

      String label = (dominant['label'] ??
          dominant['emotion'] ??
          'neutral')
          .toString()
          .toLowerCase();

      double conf =
          (dominant['confidence'] as num?)?.toDouble() ?? 0.0;

      if (conf == 0.0 && allEmotions.isNotEmpty) {
        final max = allEmotions.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        label = max.key;
        conf = max.value;
      }

      if (allEmotions.isEmpty) {
        allEmotions[label] = conf;
      }

      final timelineList =
          (json['timeline'] ?? json['segments']) as List? ?? [];

      final parsedTimeline =
      timelineList.whereType<Map<String, dynamic>>().toList();

      return EmotionResult(
        emotion: label,
        confidence: conf,
        allEmotions: allEmotions,
        timestamp: DateTime.tryParse(
            (json['timestamp'] ?? json['createdAt'])
                ?.toString() ??
                '') ??
            DateTime.now(),
        type: 'audio',
        analysisId: analysisId,
        timeline:
        parsedTimeline.isNotEmpty ? parsedTimeline : null,
      );
    } catch (e) {
      debugPrint('Audio parsing error: $e');
      return EmotionResult.empty();
    }
  }

  // ================= HISTORY =================

  factory EmotionResult.fromHistoryItem(
      Map<String, dynamic> item) {
    try {
      final data = item['result'] is Map<String, dynamic>
          ? item['result']
          : item;

      final type =
          item['type']?.toString().toLowerCase() ?? 'text';

      final fullData = <String, dynamic>{
        ...data,
        'id': item['id'],
        'timestamp': item['triggered_at'] ??
            item['timestamp'] ??
            data['timestamp']
      };

      return type == 'audio'
          ? EmotionResult.fromAudioApiV2(fullData)
          : EmotionResult.fromTextApiV2(fullData);
    } catch (e) {
      debugPrint('History parse error: $e');
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
    if (timeline != null) 'timeline': timeline,
  };
}

// ============================================================
// USER MODEL (minor fix)
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
      createdAt: DateTime.tryParse(
          json['created_at'] ?? '') ??
          DateTime.now(),
    );
  }
}

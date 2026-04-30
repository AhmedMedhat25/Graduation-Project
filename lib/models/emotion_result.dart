import 'package:flutter/foundation.dart';

class EmotionResult {
  final String emotion;
  final String category;
  final double confidence;
  final Map<String, double> allEmotions;
  final DateTime timestamp;
  final String type;
  final int? analysisId;
  final String? clientId;
  final List<Map<String, dynamic>>? timeline;

  const EmotionResult({
    required this.emotion,
    this.category = 'neutral',
    required this.confidence,
    required this.allEmotions,
    required this.timestamp,
    required this.type,
    this.analysisId,
    this.clientId,
    this.timeline,
  });

  factory EmotionResult.empty() => EmotionResult(
    emotion: 'neutral',
    confidence: 0.0,
    allEmotions: const {'neutral': 0.0},
    timestamp: DateTime.now(),
    type: 'unknown',
  );

  String? get deleteKey => clientId ?? analysisId?.toString();

  double get confidencePercent => confidence * 100;

  String get displayEmotion =>
      emotion.isEmpty ? '-' : emotion[0].toUpperCase() + emotion.substring(1);

  List<Map<String, dynamic>> get safeTimeline => timeline ?? const [];

  static DateTime parseCairoTime(dynamic rawTimestamp) {
    if (rawTimestamp == null || rawTimestamp.toString().isEmpty) {
      return DateTime.now().toUtc().add(const Duration(hours: 3));
    }
    
    String str = rawTimestamp.toString();
    // If it looks like a raw datetime without timezone info, force UTC
    if (!str.endsWith('Z') && str.length == 19) {
      str += 'Z';
    }
    
    final dt = DateTime.tryParse(str) ?? DateTime.now().toUtc();
    return dt.toUtc().add(const Duration(hours: 3));
  }

  factory EmotionResult.fromJson(Map<String, dynamic> json, String fallbackType) {
    return EmotionResult(
      emotion: (json['emotion'] ?? 'neutral').toString().toLowerCase(),
      category: (json['category'] ?? 'neutral').toString().toLowerCase(),
      confidence: _normalizeConfidence(json['confidence']),
      allEmotions: _parseEmotionMap(
        json['all_emotions'] ?? json['allEmotions'],
      ),
      timestamp: parseCairoTime(json['timestamp']),
      type: (json['type'] ?? fallbackType).toString().toLowerCase(),
      analysisId: _safeInt(json['analysis_id'] ?? json['analysisId'] ?? json['id']),
      clientId: json['client_id']?.toString() ?? json['clientId']?.toString(),
      timeline: _parseTimeline(json['timeline']),
    );
  }

  factory EmotionResult.fromTextApi(Map<String, dynamic> rawJson) {
    try {
      // The provided structure is the unwrapped AI response
      final json = rawJson['result'] is Map
          ? Map<String, dynamic>.from(rawJson['result'] as Map)
          : Map<String, dynamic>.from(rawJson);

      debugPrint('🧠 Parsing TEXT result: $json');

      final allEmotions = <String, double>{};

      // 1. Extract from combined_results (highest priority for multi-modal/merged results)
      _extractEmotions(json['combined_results'], allEmotions);
      
      // 2. Extract from full_text_analysis probabilities
      _extractEmotions(_nested(json, 'full_text_analysis', 'probabilities'), allEmotions);
      
      // 3. Extract from raw probabilities or all_emotions (fallbacks)
      _extractEmotions(json['probabilities'], allEmotions);
      _extractEmotions(json['all_emotions'], allEmotions);

      // --- Determine Dominant Emotion ---
      // New structure has combined_final_emotion and full_text_analysis.dominant
      final dominantSource = json['combined_final_emotion'] ?? 
                            (json['full_text_analysis'] is Map ? json['full_text_analysis']['dominant'] : null) ??
                            json['dominant'] ?? 
                            {};
      
      final dominantMap = Map<String, dynamic>.from(dominantSource is Map ? dominantSource : {});

      String emotion = (dominantMap['label'] ?? dominantMap['emotion'] ?? '').toString();
      double confidence = _normalizeConfidence(
        dominantMap['confidence'] ?? dominantMap['confidence_percent'],
      );

      // --- Fallback to highest in map if dominant is missing ---
      if ((emotion.isEmpty || confidence == 0.0) && allEmotions.isNotEmpty) {
        final top = allEmotions.entries.reduce((a, b) => a.value >= b.value ? a : b);
        emotion = top.key;
        confidence = top.value;
      }

      if (emotion.isEmpty) {
        emotion = (json['emotion'] ?? json['label'] ?? 'neutral').toString().toLowerCase();
      }

      if (allEmotions.isEmpty && emotion.isNotEmpty) {
        allEmotions[emotion.toLowerCase()] = confidence;
      }

      return EmotionResult(
        emotion: emotion.isEmpty ? 'neutral' : emotion.toLowerCase(),
        category: (dominantMap['category'] ?? 'neutral').toString().toLowerCase(),
        confidence: confidence,
        allEmotions: allEmotions,
        timestamp: parseCairoTime(json['timestamp']),
        type: 'text',
        analysisId: _safeInt(rawJson['id']) ?? _safeInt(json['id']),
        clientId: rawJson['client_id']?.toString() ?? json['client_id']?.toString(),
        timeline: _parseTimeline(
          json['sentences_analysis'] ?? json['timeline'],
        ),
      );
    } catch (e, st) {
      debugPrint('⚠️ Text parsing error: $e\n$st');
      debugPrint('⚠️ Raw TEXT JSON: $rawJson');
      return EmotionResult.empty();
    }
  }

  factory EmotionResult.fromAudioApi(Map<String, dynamic> rawJson) {
    try {
      final json = rawJson['result'] is Map
          ? Map<String, dynamic>.from(rawJson['result'] as Map)
          : Map<String, dynamic>.from(rawJson);

      debugPrint('🧠 Parsing AUDIO result: $json');

      final audioEmotion = json['audio_emotion'] is Map
          ? Map<String, dynamic>.from(json['audio_emotion'] as Map)
          : null;

      final allEmotions = <String, double>{};

      _extractEmotions(json['final_multimodal_results'], allEmotions);
      _extractEmotions(json['combined_results'], allEmotions);
      _extractEmotions(json['probabilities'], allEmotions);
      _extractEmotions(json['all_emotions'], allEmotions);
      _extractEmotions(audioEmotion?['probabilities'], allEmotions);

      final dominant = _extractDominant(json, [
        'final_multimodal_emotion',
        'combined_final_emotion',
        'dominant',
        'emotion',
      ], nested: [
        ['audio_emotion', 'dominant']
      ]);

      String emotion = dominant['label'] ?? dominant['emotion'] ?? '';
      double confidence = _normalizeConfidence(
        dominant['confidence'] ?? dominant['confidence_percent'],
      );

      if ((emotion.isEmpty || confidence == 0.0) && allEmotions.isNotEmpty) {
        final top = allEmotions.entries.reduce((a, b) => a.value >= b.value ? a : b);
        emotion = top.key;
        confidence = top.value;
      }

      if (emotion.isEmpty) {
        emotion = (json['emotion'] ?? json['label'] ?? 'neutral').toString().toLowerCase();
      }

      if (allEmotions.isEmpty) {
        allEmotions[emotion] = confidence;
      }

      return EmotionResult(
        emotion: emotion.isEmpty ? 'neutral' : emotion.toLowerCase(),
        category: (dominant['category'] ?? 'neutral').toString().toLowerCase(),
        confidence: confidence,
        allEmotions: allEmotions,
        timestamp: parseCairoTime(json['timestamp']),
        type: 'audio',
        analysisId: _safeInt(rawJson['id']) ?? _safeInt(json['id']),
        clientId: rawJson['client_id']?.toString() ?? json['client_id']?.toString(),
        timeline: _parseTimeline(
          audioEmotion?['timeline'] ?? json['timeline'],
        ),
      );
    } catch (e, st) {
      debugPrint('⚠️ Audio parsing error: $e\n$st');
      debugPrint('⚠️ Raw AUDIO JSON: $rawJson');
      return EmotionResult.empty();
    }
  }

  factory EmotionResult.fromHistoryItem(Map<String, dynamic> item) {
    try {
      debugPrint('📋 History item keys: ${item.keys.toList()}');

      // --- Extract emotion label ---
      String emotion = '';

      // Direct field names
      final rawEmotion = item['dominant_emotion'] ??
          item['emotion'] ??
          item['label'];

      if (rawEmotion is String && rawEmotion.isNotEmpty) {
        emotion = rawEmotion.toLowerCase();
      }

      // Try nested dominant object
      if (emotion.isEmpty && item['dominant'] is Map) {
        final dom = item['dominant'] as Map;
        emotion = (dom['label'] ?? dom['emotion'] ?? '').toString().toLowerCase();
      }

      // Try nested result object
      if (emotion.isEmpty && item['result'] is Map) {
        final res = item['result'] as Map;
        final cfe = res['combined_final_emotion'];
        if (cfe is Map) {
          emotion = (cfe['label'] ?? '').toString().toLowerCase();
        }
        if (emotion.isEmpty) {
          final dom = res['dominant'];
          if (dom is Map) {
            emotion = (dom['label'] ?? '').toString().toLowerCase();
          }
        }
        if (emotion.isEmpty) {
          emotion = (res['emotion'] ?? res['label'] ?? '').toString().toLowerCase();
        }
      }

      if (emotion.isEmpty) emotion = 'neutral';

      // --- Extract confidence ---
      double confidence = _normalizeConfidence(
        item['confidence'] ?? item['confidence_percent'] ?? item['score'],
      );

      // Try nested dominant
      if (confidence == 0.0 && item['dominant'] is Map) {
        confidence = _normalizeConfidence(
          (item['dominant'] as Map)['confidence'] ??
          (item['dominant'] as Map)['confidence_percent'],
        );
      }

      // Try nested result
      if (confidence == 0.0 && item['result'] is Map) {
        final res = item['result'] as Map;
        final cfe = res['combined_final_emotion'];
        if (cfe is Map) {
          confidence = _normalizeConfidence(
            cfe['confidence'] ?? cfe['confidence_percent'],
          );
        }
      }

      debugPrint('📋 Parsed history → emotion: $emotion, confidence: $confidence');

      return EmotionResult(
        emotion: emotion,
        confidence: confidence,
        allEmotions: {emotion: confidence},
        timestamp: parseCairoTime(item['timestamp']),
        type: (item['type'] ?? 'text').toString().toLowerCase(),
        analysisId: _safeInt(item['id']),
        clientId: item['client_id']?.toString(),
      );
    } catch (e, st) {
      debugPrint('⚠️ History parsing error: $e\n$st');
      return EmotionResult.empty();
    }
  }

  Map<String, dynamic> toJson() => {
    'emotion': emotion,
    'category': category,
    'confidence': confidence,
    'all_emotions': allEmotions,
    'timestamp': timestamp.toIso8601String(),
    'type': type,
    if (analysisId != null) 'analysis_id': analysisId,
    if (clientId != null) 'client_id': clientId,
    if (timeline != null) 'timeline': timeline,
  };

  static Map<String, dynamic> _extractDominant(
      Map<String, dynamic> json,
      List<String> directKeys, {
        List<List<String>> nested = const [],
      }) {
    for (final key in directKeys) {
      final value = json[key];
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      if (value is String) {
        return {'label': value};
      }
    }

    for (final pair in nested) {
      if (pair.length != 2) continue;
      final parent = json[pair[0]];
      if (parent is Map && parent[pair[1]] is Map) {
        return Map<String, dynamic>.from(parent[pair[1]]);
      }
    }

    return {};
  }

  static double _normalizeConfidence(dynamic value) {
    final v = _safeDouble(value) ?? 0.0;
    return v > 1.0 ? v / 100.0 : v;
  }

  static double? _safeDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static dynamic _nested(Map<String, dynamic> json, String outer, String inner) {
    final outerValue = json[outer];
    if (outerValue is Map) return outerValue[inner];
    return null;
  }

  static Map<String, double> _parseEmotionMap(dynamic raw) {
    final result = <String, double>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        result[key.toString().toLowerCase()] = _normalizeConfidence(value);
      });
    }
    return result;
  }

  static List<Map<String, dynamic>>? _parseTimeline(dynamic raw) {
    if (raw is! List) return null;

    final list = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return list.isEmpty ? null : list;
  }

  static void _extractEmotions(dynamic raw, Map<String, double> out) {
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;

        final map = Map<String, dynamic>.from(item);
        final label =
        (map['label'] ?? map['emotion'] ?? '').toString().toLowerCase();
        if (label.isEmpty) continue;

        out[label] = _normalizeConfidence(
          map['confidence'] ?? map['score'] ?? map['confidence_percent'],
        );
      }
    } else if (raw is Map) {
      raw.forEach((key, value) {
        out[key.toString().toLowerCase()] = _normalizeConfidence(value);
      });
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['firstName']?.toString();
    final lastName = json['lastName']?.toString();

    final combinedName = [
      if (firstName != null && firstName.isNotEmpty) firstName,
      if (lastName != null && lastName.isNotEmpty) lastName,
    ].join(' ');

    return UserModel(
      id: (json['user_id'] ?? json['id'] ?? '').toString(),
      name: (json['name']?.toString().isNotEmpty == true
          ? json['name'].toString()
          : combinedName.isNotEmpty
          ? combinedName
          : 'Unknown')
          .trim(),
      email: json['email']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

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
  /// Short display text from history summary (null for live analyses)
  final String? summaryText;

  const EmotionResult({
    required this.emotion,
    required this.category,
    required this.confidence,
    required this.allEmotions,
    required this.timestamp,
    required this.type,
    this.analysisId,
    this.clientId,
    this.timeline,
    this.summaryText,
  });

  // =========================
  // NORMALIZATION
  // =========================

  static String normalizeEmotionKey(String raw) {
    final k = raw.trim().toLowerCase();

    switch (k) {
      case 'happy':
      case 'happiness':
      case 'joy':
        return 'joy';

      case 'sad':
      case 'sadness':
        return 'sadness';

      case 'angry':
      case 'anger':
        return 'anger';

      case 'fearful':
      case 'fear':
        return 'fear';

      case 'surprised':
      case 'surprise':
        return 'surprise';

      case 'disgusted':
      case 'disgust':
        return 'disgust';

      case 'neutral':
        return 'neutral';

      default:
        return 'neutral';
    }
  }

  static String _normalizeCategory(String raw) {
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return 'neutral';

    switch (v) {
      case 'positive':
      case 'negative':
      case 'neutral':
        return v;
      default:
        return 'neutral';
    }
  }

  static String normalizeType(String raw) {
    final v = raw.trim().toLowerCase();

    switch (v) {
      case 'image':
      case 'photo':
        return 'photo';
      case 'audio':
      case 'voice':
      case 'speech':
        return 'audio';
      case 'video':
        return 'video';
      case 'text':
        return 'text';
      default:
        return 'unknown';
    }
  }

  static Map<String, double> normalizeAllEmotions(Map<String, double> raw) {
    final result = <String, double>{};

    raw.forEach((key, value) {
      final normKey = normalizeEmotionKey(key);
      result[normKey] = (result[normKey] ?? 0.0) + _clampConfidence(value);
    });

    return result;
  }

  // =========================
  // EMPTY SAFE OBJECT
  // =========================

  static DateTime _utcNow() => DateTime.now().toUtc();

  factory EmotionResult.empty() => EmotionResult(
    emotion: 'neutral',
    category: 'neutral',
    confidence: 0.0,
    allEmotions: const {'neutral': 0.0},
    timestamp: _utcNow(),
    type: 'unknown',
  );

  // =========================
  // NORMAL CONSTRUCTOR ENTRY
  // =========================

  factory EmotionResult.create({
    required String emotion,
    String category = 'neutral',
    required double confidence,
    required Map<String, double> allEmotions,
    required DateTime timestamp,
    required String type,
    int? analysisId,
    String? clientId,
    List<Map<String, dynamic>>? timeline,
    String? summaryText,
  }) {
    final normalizedEmotion = normalizeEmotionKey(emotion);
    final normalizedConfidence = _clampConfidence(confidence);
    final normalizedMap = normalizeAllEmotions(allEmotions);
    final safeMap = _ensureDominantInMap(
      dominantEmotion: normalizedEmotion,
      confidence: normalizedConfidence,
      source: normalizedMap,
    );

    return EmotionResult(
      emotion: normalizedEmotion,
      category: _normalizeCategory(category),
      confidence: normalizedConfidence,
      allEmotions: safeMap,
      timestamp: timestamp.toUtc(),
      type: normalizeType(type),
      analysisId: analysisId,
      clientId: clientId,
      timeline: timeline == null || timeline.isEmpty ? null : timeline,
      summaryText: summaryText?.trim().isNotEmpty == true ? summaryText!.trim() : null,
    );
  }

  // =========================
  // HELPERS
  // =========================

  double get confidencePercent => confidence * 100;

  String get displayEmotion =>
      emotion.isEmpty ? '-' : emotion[0].toUpperCase() + emotion.substring(1);

  List<Map<String, dynamic>> get safeTimeline => timeline ?? const [];

  String? get deleteKey => clientId ?? analysisId?.toString();

  /// Returns the timestamp converted to Cairo time (UTC+3) for display.
  DateTime get cairoTimestamp => toCairoTime(timestamp);

  /// Returns Cairo-time ISO-8601 string for display purposes.
  String get displayTimestampIso => cairoTimestamp.toIso8601String();

  // =========================
  // SAFE PARSING HELPERS
  // =========================

  static double _safeDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  static double _clampConfidence(double v) {
    if (v.isNaN || v.isInfinite) return 0.0;
    if (v < 0) return 0.0;
    if (v > 1) return 1.0;
    return v;
  }

  static int? _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is double) return v.round();
    return null;
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  /// Parse a timestamp to real UTC.
  /// - If no timezone info present, treat as UTC from backend.
  /// - If timezone info present (Z, +HH:MM, -HH:MM), parse and convert to UTC.
  /// - Falls back to current UTC on null/invalid input.
  static DateTime _parseTime(dynamic v) {
    try {
      if (v == null) return _utcNow();

      final s = v.toString().trim();
      if (s.isEmpty) return _utcNow();

      final hasTimezone = s.endsWith('Z') ||
          RegExp(r'[+-][0-9]{2}:[0-9]{2}$').hasMatch(s);

      final normalized = hasTimezone ? s : '${s}Z';

      var parsed = DateTime.tryParse(normalized);
      if (parsed != null) {
        parsed = parsed.toUtc();
        // Timezone heuristic: If the parsed date is in the future relative to UTC now
        // by more than 10 minutes, it likely represents Cairo local time (UTC+3)
        // that was incorrectly parsed as UTC. Convert it to true UTC by subtracting 3 hours.
        final now = DateTime.now().toUtc();
        if (parsed.difference(now).inMinutes > 10) {
          parsed = parsed.subtract(const Duration(hours: 3));
        }
        return parsed;
      }

      return _utcNow();
    } catch (_) {
      return _utcNow();
    }
  }

  static Map<String, dynamic> _unwrapResult(Map<String, dynamic> rawJson) {
    if (rawJson['result'] is Map) {
      return Map<String, dynamic>.from(rawJson['result']);
    }
    return Map<String, dynamic>.from(rawJson);
  }

  // =========================
  // EMOTION MAP PARSERS
  // =========================

  static Map<String, double> _parseEmotions(dynamic raw) {
    final result = <String, double>{};

    if (raw is Map) {
      raw.forEach((key, value) {
        final label = key.toString().toLowerCase();

        if (value is Map) {
          result[label] = _safeDouble(value['confidence'] ?? value['score']);
        } else {
          result[label] = _safeDouble(value);
        }
      });
    }

    return normalizeAllEmotions(result);
  }

  static Map<String, double> _parseEmotionsList(dynamic raw) {
    final result = <String, double>{};

    if (raw is List) {
      for (final item in raw) {
        if (item is Map && item['label'] != null) {
          final label = item['label'].toString().toLowerCase();
          final score = _safeDouble(item['confidence'] ?? item['score']);
          result[label] = score;
        }
      }
    }

    return normalizeAllEmotions(result);
  }

  static List<Map<String, dynamic>>? _parseTimeline(dynamic raw) {
    if (raw is! List) return null;

    final list = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return list.isEmpty ? null : list;
  }

  /// Merges multiple emotion maps. Later maps in the list take priority
  /// for overlapping keys, so put the most authoritative source last.
  static Map<String, double> _mergeEmotionMaps(
      List<Map<String, double>> maps,
      ) {
    final result = <String, double>{};

    for (final map in maps) {
      for (final entry in map.entries) {
        // Only overwrite if the new source actually has a meaningful value,
        // OR if no value exists yet.
        if (entry.value > 0 || !result.containsKey(entry.key)) {
          result[entry.key] = entry.value;
        }
      }
    }

    return normalizeAllEmotions(result);
  }

  static ({String emotion, double confidence}) _resolveDominant({
    required Map<String, dynamic>? dominant,
    required Map<String, dynamic> json,
    required Map<String, double> allEmotions,
  }) {
    String emotion = normalizeEmotionKey(
      (dominant?['label'] ?? dominant?['emotion'] ?? json['emotion'] ?? 'neutral')
          .toString(),
    );

    double confidence = _clampConfidence(
      _safeDouble(
        dominant?['confidence'] ?? dominant?['score'] ?? json['confidence'],
      ),
    );

    if ((emotion.isEmpty || emotion == 'neutral') &&
        allEmotions.isNotEmpty &&
        !allEmotions.containsKey('neutral')) {
      final top = allEmotions.entries.reduce((a, b) => a.value >= b.value ? a : b);
      emotion = top.key;
      confidence = top.value;
    }

    if (confidence == 0.0 && allEmotions.isNotEmpty) {
      final top = allEmotions.entries.reduce((a, b) => a.value >= b.value ? a : b);
      emotion = top.key;
      confidence = top.value;
    }

    return (
    emotion: normalizeEmotionKey(emotion),
    confidence: _clampConfidence(confidence),
    );
  }

  static Map<String, double> _ensureDominantInMap({
    required String dominantEmotion,
    required double confidence,
    required Map<String, double> source,
  }) {
    final result = Map<String, double>.from(source);
    final normalizedEmotion = normalizeEmotionKey(dominantEmotion);
    final safeConfidence = _clampConfidence(confidence);

    if (result.isEmpty) {
      result[normalizedEmotion] = safeConfidence;
      return result;
    }

    if (normalizedEmotion.isNotEmpty) {
      result[normalizedEmotion] = safeConfidence > 0
          ? safeConfidence
          : (result[normalizedEmotion] ?? 0.0);
    }

    return normalizeAllEmotions(result);
  }

  // =========================
  // GENERIC BUILDER
  // =========================

  static EmotionResult _buildGeneric({
    required Map<String, dynamic> rawJson,
    required String type,
    Map<String, dynamic>? dominant,
    List<Map<String, double>> emotionSources = const [],
    List<Map<String, dynamic>>? timeline,
    String? categoryOverride,
    dynamic timestampOverride,
    int? analysisIdOverride,
    String? clientIdOverride,
  }) {
    final json = _unwrapResult(rawJson);

    final allEmotions = _mergeEmotionMaps(emotionSources);

    final resolved = _resolveDominant(
      dominant: dominant,
      json: json,
      allEmotions: allEmotions,
    );

    return EmotionResult.create(
      emotion: resolved.emotion,
      category: categoryOverride ??
          (dominant?['category'] ?? json['category'] ?? 'neutral').toString(),
      confidence: resolved.confidence,
      allEmotions: allEmotions,
      timestamp: _parseTime(timestampOverride ?? json['timestamp']),
      type: type,
      analysisId: analysisIdOverride ?? _safeInt(rawJson['id'] ?? json['id']),
      clientId: clientIdOverride ?? rawJson['client_id']?.toString(),
      timeline: timeline,
    );
  }

  // =========================
  // TEXT API
  // =========================

  factory EmotionResult.fromTextApi(Map<String, dynamic> rawJson) {
    try {
      final json = _unwrapResult(rawJson);

      debugPrint('🧠 TEXT PARSE keys: ${json.keys.toList()}');

      final src1 = _parseEmotions(json['probabilities']);
      final src2 = _parseEmotions(json['all_emotions']);

      final fta = _map(json['full_text_analysis']);
      final src3 = _parseEmotions(fta?['probabilities']);

      final src4 = _parseEmotionsList(json['combined_results']);

      final dominant = _map(json['combined_final_emotion']) ??
          _map(json['dominant']) ??
          _map(json['full_text_analysis']);

      final timeline = _parseTimeline(json['timeline'] ?? json['sentences_analysis']);

      return _buildGeneric(
        rawJson: rawJson,
        type: 'text',
        dominant: dominant,
        emotionSources: [src1, src2, src3, src4],
        timeline: timeline,
        categoryOverride:
        (dominant?['category'] ?? json['category'] ?? 'neutral').toString(),
      );
    } catch (e, st) {
      debugPrint('❌ TEXT PARSE ERROR: $e\n$st');
      return EmotionResult.empty();
    }
  }

  // =========================
  // AUDIO API
  // =========================

  factory EmotionResult.fromAudioApi(Map<String, dynamic> rawJson) {
    try {
      final json = _unwrapResult(rawJson);

      debugPrint('🎧 AUDIO PARSE keys: ${json.keys.toList()}');

      final audioEmo = _map(json['audio_emotion']);
      final textEmo = _map(json['text_emotion']);

      // ── Gather emotion sources (low → high priority) ──
      // Less authoritative first, most authoritative LAST.
      final src1 = _parseEmotions(json['probabilities']);
      final src2 = _parseEmotions(json['all_emotions']);
      final src3 = _parseEmotions(audioEmo?['probabilities']);
      final src4 = _parseEmotions(textEmo?['probabilities']);
      final srcCombined = _parseEmotionsList(json['combined_results']);
      // final_multimodal_results is the AUTHORITATIVE result from the API
      final srcMultimodal = _parseEmotionsList(json['final_multimodal_results']);

      // When audio_emotion.probabilities is absent, pull probabilities from the
      // first timeline segment as a fallback so the emotion bar is never empty.
      Map<String, double> fallbackTimelineProbs = {};
      if (audioEmo?['timeline'] is List && src3.isEmpty) {
        final segments = audioEmo!['timeline'] as List;
        if (segments.isNotEmpty && segments.first is Map) {
          fallbackTimelineProbs = _parseEmotions((segments.first as Map)['probabilities']);
        }
      }

      // audioT takes priority over json['timeline'] so textT cannot accidentally
      // consume the same key and orphan the audio segments.
      final audioT = _parseTimeline(audioEmo?['timeline'] ?? json['timeline']);
      final textT = _parseTimeline(
        json['segments'] ??
        textEmo?['sentences_analysis'] ??
        textEmo?['timeline'],
      );

      List<Map<String, dynamic>>? timeline;

      if (audioT != null && textT != null) {
        timeline = List<Map<String, dynamic>>.from(audioT);
        for (final segment in timeline) {
          double start = _safeDouble(
            segment['start'] ??
            segment['start_time'] ??
            segment['time'] ??
            segment['timestamp_offset'] ??
            segment['offset'] ??
            segment['segment_index'] ?? 0);
          // Normalize audio start ms → s if suspiciously large (matches text-side normalization)
          if (start > 1000) start /= 1000.0;

          Map<String, dynamic>? closestText;
          double minDiff = 99999.0;
          for (final ts in textT) {
            double tStart = _safeDouble(ts['start'] ?? ts['start_time'] ?? ts['time'] ?? ts['timestamp_offset'] ?? ts['offset'] ?? ts['segment_index'] ?? 0);
            // Normalize milliseconds → seconds when the value is suspiciously large
            // (speech-to-text APIs often return timestamps in ms, audio in seconds).
            if (tStart > 1000) tStart /= 1000.0;
            final diff = (tStart - start).abs();
            if (diff < minDiff) {
              minDiff = diff;
              closestText = ts;
            }
          }
          // If a text segment is close enough in time, attach its quote
          if (closestText != null && minDiff <= 5.0) {
            segment['text'] =
              closestText['text'] ??
              closestText['sentence'] ??
              closestText['segment_text'] ??
              closestText['quote'] ??
              closestText['transcript'] ??
              closestText['words'] ??
              closestText['content'] ??
              closestText['speech'];
          }
        }
      } else {
        timeline = audioT ?? textT;
      }

      if (timeline != null) {
        timeline.sort((a, b) {
          // Use whichever timestamp key is present (audio uses 'start'/'start_time').
          final aVal = a['start'] ?? a['start_time'] ?? a['time']
              ?? a['segment_index'] ?? a['timestamp_offset'] ?? 0;
          final bVal = b['start'] ?? b['start_time'] ?? b['time']
              ?? b['segment_index'] ?? b['timestamp_offset'] ?? 0;
          final aNum = aVal is num ? aVal.toDouble() : (double.tryParse(aVal.toString()) ?? 0.0);
          final bNum = bVal is num ? bVal.toDouble() : (double.tryParse(bVal.toString()) ?? 0.0);
          return aNum.compareTo(bNum);
        });

        // Post-process: for segments that have no 'text' yet, check if the
        // audio segment itself carries a transcript field from the API,
        // or fall back to the top-level transcribed text.
        final topLevelText = json['transcribed_text'] ??
            json['text'] ??
            json['transcript'] ??
            json['speech'] ??
            audioEmo?['transcribed_text'] ??
            textEmo?['transcribed_text'] ??
            textEmo?['text'];

        for (final segment in timeline) {
          if (segment['text'] == null || (segment['text'] as String?)?.isEmpty == true) {
            final fallbackText = segment['transcript'] ??
              segment['words'] ??
              segment['content'] ??
              segment['speech'] ??
              segment['sentence'] ??
              topLevelText;

            segment['text'] = fallbackText?.toString().trim();
          }
        }
      }

      Map<String, double> srcTimeline = {};
      if (timeline != null && timeline.isNotEmpty) {
        final Map<String, double> sums = {};
        int count = 0;
        for (final segment in timeline) {
          final probs = _map(segment['probabilities']);
          if (probs != null) {
            probs.forEach((k, v) {
              final normK = normalizeEmotionKey(k);
              sums[normK] = (sums[normK] ?? 0.0) + _safeDouble(v);
            });
            count++;
          } else {
            final dom = _map(segment['dominant']);
            if (dom != null) {
              final label = normalizeEmotionKey(dom['label'] ?? dom['emotion'] ?? '');
              final score = _safeDouble(dom['confidence'] ?? dom['score'] ?? dom['confidence_percent']);
              if (label.isNotEmpty) {
                sums[label] = (sums[label] ?? 0.0) + (score > 1.0 ? score / 100.0 : score);
                count++; // fix: dominant-only segments must be counted too
              }
            }
          }
        }
        if (count > 0) {
          sums.forEach((k, v) {
            srcTimeline[k] = v / count;
          });
        } else if (sums.isNotEmpty) {
          final total = sums.values.fold(0.0, (a, b) => a + b);
          if (total > 0) {
            sums.forEach((k, v) {
              srcTimeline[k] = v / total;
            });
          }
        }
      }

      // ── Resolve dominant emotion ──
      // Prefer final_multimodal_emotion (the API's authoritative label)
      final dominant = _map(json['final_multimodal_emotion']) ??
          _map(json['combined_final_emotion']) ??
          _map(audioEmo?['dominant']) ??
          _map(json['dominant']);

      Map<String, dynamic>? resolvedDominant = dominant;
      if (resolvedDominant == null && srcTimeline.isNotEmpty) {
        final top = srcTimeline.entries.reduce((a, b) => a.value > b.value ? a : b);
        resolvedDominant = {
          'label': top.key,
          'confidence': top.value,
          'category': top.key == 'joy' ? 'positive' : (top.key == 'neutral' ? 'neutral' : 'negative'),
        };
      }

      debugPrint('🎧 AUDIO dominant: ${resolvedDominant?['label']}');
      debugPrint('🎧 AUDIO srcMultimodal: $srcMultimodal');
      debugPrint('🎧 AUDIO srcCombined: $srcCombined');
      debugPrint('🎧 AUDIO srcTimeline: $srcTimeline');

      // ── Build result ──
      // Order matters: last source wins for overlapping keys.
      // For Audio API, acoustic sources (src3, srcTimeline) must be LAST
      // so the overall result matches what the acoustic timeline chart shows!
      final resolvedSources = [
        if (fallbackTimelineProbs.isNotEmpty) fallbackTimelineProbs,
        if (srcMultimodal.isNotEmpty) srcMultimodal,
        if (srcCombined.isNotEmpty) srcCombined,
        if (src4.isNotEmpty) src4,
        if (src1.isNotEmpty) src1,
        if (src2.isNotEmpty) src2,
        if (src3.isNotEmpty) src3,
        if (srcTimeline.isNotEmpty) srcTimeline,
      ];

      // If the timeline was empty, fallback to the resolved dominant emotion.
      // Otherwise, the timeline average IS the dominant emotion.
      Map<String, dynamic>? finalDominant = resolvedDominant;
      if (srcTimeline.isNotEmpty) {
        final top = srcTimeline.entries.reduce((a, b) => a.value > b.value ? a : b);
        finalDominant = {
          'label': top.key,
          'confidence': top.value,
          'category': top.key == 'joy' ? 'positive' : (top.key == 'neutral' ? 'neutral' : 'negative'),
        };
      }

      return _buildGeneric(
        rawJson: rawJson,
        type: 'audio',
        dominant: finalDominant,
        emotionSources: resolvedSources,
        timeline: timeline,
        categoryOverride:
        (resolvedDominant?['category'] ?? json['category'] ?? 'neutral').toString(),
      );
    } catch (e, st) {
      debugPrint('❌ AUDIO PARSE ERROR: $e\n$st');
      return EmotionResult.empty();
    }
  }

  // =========================
  // PHOTO API
  // =========================

  factory EmotionResult.fromPhotoApi(Map<String, dynamic> rawJson) {
    try {
      final json = _unwrapResult(rawJson);

      debugPrint('📸 PHOTO PARSE keys: ${json.keys.toList()}');

      final faces = json['faces'];
      Map<String, dynamic>? firstFace;
      if (faces is List && faces.isNotEmpty) {
        firstFace = _map(faces.first);
      }

      final sceneEmo = _map(json['scene_emotion']) ?? _map(json['overall_emotion']);
      final imageEmo = _map(json['image_emotion']);
      final fullAnalysis = _map(json['full_image_analysis']);

      final firstFaceEmotion = _map(firstFace?['emotion']);

      final src1 = _parseEmotions(firstFace?['probabilities']);
      final src2 = _parseEmotions(firstFaceEmotion?['probabilities']);
      final src3 = _parseEmotionsList(firstFace?['combined_results']);
      final src4 = _parseEmotions(json['probabilities']);
      final src5 = _parseEmotions(json['all_emotions']);
      final src6 = _parseEmotions(imageEmo?['probabilities']);
      final src7 = _parseEmotions(fullAnalysis?['probabilities']);
      final src8 = _parseEmotionsList(json['final_multimodal_results']);
      final src9 = _parseEmotionsList(json['combined_results']);

      Map<String, double> sceneMap = {};
      if (sceneEmo != null) {
        final label =
        (sceneEmo['label'] ?? sceneEmo['emotion'])?.toString().toLowerCase();
        final conf = _safeDouble(sceneEmo['confidence'] ?? sceneEmo['score']);
        if (label != null && label.isNotEmpty) {
          sceneMap[label] = conf;
        }
      }

      final dominant = _map(firstFace?['combined_final_emotion']) ??
          _map(firstFace?['emotion']) ??
          sceneEmo ??
          _map(json['final_multimodal_emotion']) ??
          _map(json['combined_final_emotion']) ??
          _map(imageEmo?['dominant']) ??
          _map(json['dominant']);

      final timeline = _parseTimeline(json['timeline']);

      return _buildGeneric(
        rawJson: rawJson,
        type: 'photo',
        dominant: dominant,
        emotionSources: [
          src1,
          src2,
          src3,
          sceneMap,
          src4,
          src5,
          src6,
          src7,
          src8,
          src9,
        ],
        timeline: timeline,
        categoryOverride:
        (dominant?['category'] ?? json['category'] ?? 'neutral').toString(),
      );
    } catch (e, st) {
      debugPrint('❌ PHOTO PARSE ERROR: $e\n$st');
      return EmotionResult.empty();
    }
  }

  // =========================
  // VIDEO API
  // =========================

  factory EmotionResult.fromVideoApi(Map<String, dynamic> rawJson) {
    try {
      final json = _unwrapResult(rawJson);

      debugPrint('🎥 VIDEO PARSE keys: ${json.keys.toList()}');

      final faces = json['faces'];
      Map<String, dynamic>? firstFace;
      if (faces is List && faces.isNotEmpty) {
        firstFace = _map(faces.first);
      }

      final videoEmo = _map(json['video_emotion']);
      final fullAnalysis = _map(json['full_video_analysis']);
      final sceneEmo = _map(json['overall_emotion']) ?? _map(json['scene_emotion']);
      final firstFaceEmotion = _map(firstFace?['emotion']);

      final src1 = _parseEmotions(firstFace?['probabilities']);
      final src2 = _parseEmotions(firstFaceEmotion?['probabilities']);
      final src3 = _parseEmotionsList(firstFace?['combined_results']);
      final src4 = _parseEmotions(json['probabilities']);
      final src5 = _parseEmotions(json['all_emotions']);
      final src6 = _parseEmotions(videoEmo?['probabilities']);
      final src7 = _parseEmotions(fullAnalysis?['probabilities']);
      final src8 = _parseEmotionsList(json['final_multimodal_results']);
      final src9 = _parseEmotionsList(json['combined_results']);

      Map<String, double> sceneMap = {};
      if (sceneEmo != null) {
        final label =
        (sceneEmo['label'] ?? sceneEmo['emotion'])?.toString().toLowerCase();
        final conf = _safeDouble(sceneEmo['confidence'] ?? sceneEmo['score']);
        if (label != null && label.isNotEmpty) {
          sceneMap[label] = conf;
        }
      }

      final dominant = _map(firstFace?['combined_final_emotion']) ??
          _map(firstFace?['emotion']) ??
          sceneEmo ??
          _map(json['final_multimodal_emotion']) ??
          _map(json['combined_final_emotion']) ??
          _map(videoEmo?['dominant']) ??
          _map(json['dominant']);

      final timeline = _parseTimeline(firstFace?['timeline']) ??
          _parseTimeline(videoEmo?['timeline']) ??
          _parseTimeline(json['timeline'] ?? json['segments'] ?? json['frames']);

      Map<String, double> srcTimeline = {};
      if (timeline != null && timeline.isNotEmpty) {
        final Map<String, double> sums = {};
        int count = 0;
        for (final frame in timeline) {
          final probs = _map(frame['probabilities']);
          if (probs != null) {
            probs.forEach((k, v) {
              final normK = normalizeEmotionKey(k);
              sums[normK] = (sums[normK] ?? 0.0) + _safeDouble(v);
            });
            count++;
          } else {
            final dom = _map(frame['dominant']);
            if (dom != null) {
              final label = normalizeEmotionKey(dom['label'] ?? dom['emotion'] ?? '');
              final score = _safeDouble(dom['confidence'] ?? dom['score'] ?? dom['confidence_percent']);
              if (label.isNotEmpty) {
                sums[label] = (sums[label] ?? 0.0) + (score > 1.0 ? score / 100.0 : score);
                count++; // fix: dominant-only frames must be counted too
              }
            }
          }
        }
        if (count > 0) {
          sums.forEach((k, v) {
            srcTimeline[k] = v / count;
          });
        } else if (sums.isNotEmpty) {
          final total = sums.values.fold(0.0, (a, b) => a + b);
          if (total > 0) {
            sums.forEach((k, v) {
              srcTimeline[k] = v / total;
            });
          }
        }
      }

      Map<String, dynamic>? resolvedDominant = dominant;
      if (resolvedDominant == null && srcTimeline.isNotEmpty) {
        final top = srcTimeline.entries.reduce((a, b) => a.value > b.value ? a : b);
        resolvedDominant = {
          'label': top.key,
          'confidence': top.value,
          'category': top.key == 'joy' ? 'positive' : (top.key == 'neutral' ? 'neutral' : 'negative'),
        };
      }

      return _buildGeneric(
        rawJson: rawJson,
        type: 'video',
        dominant: resolvedDominant,
        emotionSources: [
          src1,
          src2,
          src3,
          sceneMap,
          src4,
          src5,
          src6,
          src7,
          src8,
          src9,
          srcTimeline,
        ],
        timeline: timeline,
        categoryOverride:
        (resolvedDominant?['category'] ?? json['category'] ?? 'neutral').toString(),
      );
    } catch (e, st) {
      debugPrint('❌ VIDEO PARSE ERROR: $e\n$st');
      return EmotionResult.empty();
    }
  }

  // =========================
  // TIME HELPERS (PUBLIC)
  // =========================

  /// Current time in real UTC.
  static DateTime utcNow() => _utcNow();

  /// Current Cairo time (UTC+3) — for display only, never store this.
  static DateTime cairoNow() =>
      _utcNow().add(const Duration(hours: 3));

  /// Convert any DateTime to Cairo display time (UTC+3).
  static DateTime toCairoTime(DateTime dateTime) =>
      dateTime.toUtc().add(const Duration(hours: 3));

  /// Parse a timestamp string to real UTC DateTime.
  /// Use this from external callers instead of the private _parseTime.
  static DateTime parseUtcTime(dynamic v) => _parseTime(v);

  /// @deprecated Use [parseUtcTime] instead. Kept for backward compatibility.
  static DateTime parseCairoTime(dynamic v) => _parseTime(v);

  // =========================
  // FROM JSON (LOCAL STORAGE)
  // =========================

  factory EmotionResult.fromJson(Map<String, dynamic> json, [String? typeHint]) {
    try {
      return EmotionResult.create(
        emotion: (json['emotion'] ?? 'neutral').toString(),
        category: (json['category'] ?? 'neutral').toString(),
        confidence: _safeDouble(json['confidence']),
        allEmotions: _parseEmotions(json['all_emotions']),
        timestamp: _parseTime(json['timestamp']),
        type: typeHint ?? (json['type'] ?? 'unknown').toString(),
        analysisId: _safeInt(json['analysis_id'] ?? json['id']),
        clientId: json['client_id']?.toString(),
        timeline: _parseTimeline(json['timeline']),
        summaryText: json['summary_text']?.toString(),
      );
    } catch (e, st) {
      debugPrint('❌ fromJson error: $e\n$st');
      return EmotionResult.empty();
    }
  }


  // =========================
  // FROM HISTORY ITEM (REMOTE)
  // =========================

  factory EmotionResult.fromHistoryItem(Map<String, dynamic> json) {
    try {
      // History API returns summary objects, NOT full analysis payloads.
      // Fields: id, client_id, type, dominant_emotion, emotion_category,
      //         confidence, confidence_percent, summary_text, timestamp
      final rawType =
          (json['type'] ?? 'unknown').toString().toLowerCase();
      final type = normalizeType(rawType);

      // Guard: if type is still unknown, skip this record
      if (type == 'unknown') return EmotionResult.empty();

      // ── Emotion & Confidence ──────────────────────────────────────────
      final rawEmotion =
          (json['dominant_emotion'] ?? json['emotion'] ?? 'neutral')
              .toString();
      final emotion = normalizeEmotionKey(rawEmotion);

      // confidence may arrive as 0-1 or 0-100 depending on field used
      double confidence = 0.0;
      if (json['confidence'] != null) {
        confidence = _clampConfidence((json['confidence'] as num).toDouble());
      } else if (json['confidence_percent'] != null) {
        final pct = (json['confidence_percent'] as num).toDouble();
        confidence = _clampConfidence(pct > 1 ? pct / 100.0 : pct);
      }

      // ── Category ─────────────────────────────────────────────────────
      final rawCategory =
          (json['emotion_category'] ?? json['category'] ?? 'neutral')
              .toString();

      // ── Timestamp ────────────────────────────────────────────────────
      final timestamp = _parseTime(
        json['timestamp'] ?? json['created_at'],
      );

      // ── Build a minimal allEmotions map from the dominant entry ───────
      final allEmotions = <String, double>{emotion: confidence};

      return EmotionResult.create(
        emotion: emotion,
        category: rawCategory,
        confidence: confidence,
        allEmotions: allEmotions,
        timestamp: timestamp,
        type: type,
        analysisId: _safeInt(json['id']),
        clientId: json['client_id']?.toString(),
        // History summaries don't carry timeline data
        timeline: null,
        summaryText: json['summary_text']?.toString(),
      );
    } catch (e, st) {
      debugPrint('❌ fromHistoryItem error: $e\n$st');
      return EmotionResult.empty();
    }
  }

  // =========================
  // JSON
  // =========================

  Map<String, dynamic> toJson() => {
    'emotion': emotion,
    'category': category,
    'confidence': confidence,
    'all_emotions': allEmotions,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'type': type,
    if (analysisId != null) 'analysis_id': analysisId,
    if (clientId != null) 'client_id': clientId,
    if (timeline != null) 'timeline': timeline,
    if (summaryText != null) 'summary_text': summaryText,
  };
}

// =========================
// USER MODEL
// =========================

class UserModel {
  final String? name;
  final String? email;
  final String? avatarUrl;

  const UserModel({
    this.name,
    this.email,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    String? displayName = json['name']?.toString();

    if (displayName == null || displayName.trim().isEmpty) {
      final first = json['firstName']?.toString() ?? '';
      final last = json['lastName']?.toString() ?? '';
      final combined = '$first $last'.trim();
      displayName = combined.isNotEmpty ? combined : null;
    }

    return UserModel(
      name: displayName,
      email: json['email']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}
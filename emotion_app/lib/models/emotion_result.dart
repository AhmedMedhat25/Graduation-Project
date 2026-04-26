class EmotionResult {
  final String emotion;
  final double confidence;
  final Map<String, double> allEmotions;
  final DateTime timestamp;
  final String type; // text, audio, photo, video
  final int? analysisId; // Cloud analysis ID for linking back
  final List<Map<String, dynamic>>? timeline; // For segments/sentences

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.allEmotions,
    required this.timestamp,
    required this.type,
    this.analysisId,
    this.timeline,
  });

  factory EmotionResult.fromJson(Map<String, dynamic> json, String type) {
    return EmotionResult(
      emotion: json['emotion'] ?? 'neutral',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      allEmotions: Map<String, double>.from(
        (json['all_emotions'] ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
        ),
      ),
      timestamp: DateTime.now(),
      type: type,
    );
  }

  /// Parse the V2 text analysis response from the API.
  ///
  /// The response may be flat or wrapped in a `result` key:
  /// ```json
  /// {
  ///   "id": 42,
  ///   "combined_final_emotion": {"label": "joy", "confidence": 0.87},
  ///   "combined_results": [{"label": "joy", "confidence": 0.87}, ...],
  /// }
  /// ```
  factory EmotionResult.fromTextApiV2(Map<String, dynamic> rawJson) {
    // Unwrap if the actual data is nested under "result"
    final json = (rawJson['result'] is Map<String, dynamic>
        ? rawJson['result'] as Map<String, dynamic>
        : rawJson);
    // Also check for an id at the top level
    final analysisId = rawJson['id'] as int? ?? json['id'] as int?;

    final dominant = (json['combined_final_emotion'] ?? json['combinedFinalEmotion']) as Map<String, dynamic>? ?? {};
    final label = (dominant['label'] ?? 'neutral').toString().toLowerCase();
    final conf = (dominant['confidence'] as num?)?.toDouble() ?? 0.0;

    // Build allEmotions from combined_results array
    final combinedList = (json['combined_results'] ?? json['combinedResults']) as List? ?? [];
    final allEmotions = <String, double>{};
    for (final item in combinedList) {
      final l = (item['label'] ?? '').toString().toLowerCase();
      final c = (item['confidence'] as num?)?.toDouble() ?? 0.0;
      if (l.isNotEmpty) allEmotions[l] = c;
    }
    if (allEmotions.isEmpty) {
      allEmotions[label] = conf;
    }

    // Extract timeline if available
    final sentencesList = (json['sentences_analysis'] ?? json['sentencesAnalysis']) as List? ?? [];
    List<Map<String, dynamic>>? parsedTimeline;
    if (sentencesList.isNotEmpty) {
      parsedTimeline = sentencesList.map((e) => e as Map<String, dynamic>).toList();
    }

    return EmotionResult(
      emotion: label,
      confidence: conf,
      allEmotions: allEmotions,
      timestamp: DateTime.tryParse((json['timestamp'] ?? json['createdAt'])?.toString() ?? '') ?? DateTime.now(),
      type: 'text',
      analysisId: analysisId,
      timeline: parsedTimeline,
    );
  }

  /// Parse the V2 audio analysis response from the API.
  ///
  /// The response may be flat or wrapped in a `result` key.
  factory EmotionResult.fromAudioApiV2(Map<String, dynamic> rawJson) {
    // Unwrap if the actual data is nested under "result"
    final json = (rawJson['result'] is Map<String, dynamic>
        ? rawJson['result'] as Map<String, dynamic>
        : rawJson);
    final analysisId = rawJson['id'] as int? ?? json['id'] as int?;

    final dominant = (json['final_multimodal_emotion'] ?? json['finalMultimodalEmotion']) as Map<String, dynamic>? ?? {};
    final label = (dominant['label'] ?? 'neutral').toString().toLowerCase();
    final conf = (dominant['confidence'] as num?)?.toDouble() ?? 0.0;

    // Build allEmotions from final_multimodal_results array
    final combinedList = (json['final_multimodal_results'] ?? json['finalMultimodalResults']) as List? ?? [];
    final allEmotions = <String, double>{};
    for (final item in combinedList) {
      final l = (item['label'] ?? '').toString().toLowerCase();
      final c = (item['confidence'] as num?)?.toDouble() ?? 0.0;
      if (l.isNotEmpty) allEmotions[l] = c;
    }
    if (allEmotions.isEmpty) {
      allEmotions[label] = conf;
    }

    // Extract timeline if available
    final timelineList = json['timeline'] as List? ?? [];
    List<Map<String, dynamic>>? parsedTimeline;
    if (timelineList.isNotEmpty) {
      parsedTimeline = timelineList.map((e) => e as Map<String, dynamic>).toList();
    }

    return EmotionResult(
      emotion: label,
      confidence: conf,
      allEmotions: allEmotions,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      type: 'audio',
      analysisId: analysisId,
      timeline: parsedTimeline,
    );
  }

  /// Parse a history item from /api/analysis/history
  factory EmotionResult.fromHistoryItem(Map<String, dynamic> item) {
    final rawEmotion = (item['dominantEmotion'] ?? item['dominant_emotion'])?.toString().toLowerCase().trim();
    final emotion = (rawEmotion == null || rawEmotion.isEmpty) ? 'neutral' : rawEmotion;
    final confidence = ((item['avgConfidence'] ?? item['confidence']) as num? ?? 0.0).toDouble();

    // Try to parse all emotions from the response
    final allEmotions = <String, double>{};
    final breakdown = item['emotionBreakdown'] ?? item['emotion_breakdown'];
    if (breakdown is Map) {
      breakdown.forEach((k, v) {
        allEmotions[k.toString().toLowerCase()] = (v as num).toDouble();
      });
    }
    if (allEmotions.isEmpty) {
      allEmotions[emotion] = confidence;
    }

    // Attempt to extract timeline if the backend ever provides it in history
    final sentencesList = (item['sentencesAnalysis'] ?? item['sentences_analysis']) as List? ?? [];
    final timelineList = item['timeline'] as List? ?? [];
    List<Map<String, dynamic>>? parsedTimeline;
    if (sentencesList.isNotEmpty) {
      parsedTimeline = sentencesList.map((e) => e as Map<String, dynamic>).toList();
    } else if (timelineList.isNotEmpty) {
      parsedTimeline = timelineList.map((e) => e as Map<String, dynamic>).toList();
    }

    final createdAt = item['createdAt'] ?? item['timestamp'];
    final inputType = item['inputType'] ?? item['type'];

    return EmotionResult(
      emotion: emotion,
      confidence: confidence,
      allEmotions: allEmotions,
      timestamp: DateTime.tryParse(createdAt?.toString() ?? '') ?? DateTime.now(),
      type: inputType?.toString().toLowerCase() ?? 'analysis',
      analysisId: item['id'] as int?,
      timeline: parsedTimeline,
    );
  }

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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().isNotEmpty == true 
          ? json['name'] 
          : ((json['firstName'] != null || json['lastName'] != null)
              ? '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim()
              : 'Unknown'),
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

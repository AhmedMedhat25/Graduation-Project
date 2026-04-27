import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class AudioEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();
  final _uuid = const Uuid();

  static const List<String> _emotionKeys = [
    'joy', 'sadness', 'anger', 'fear', 'surprise', 'disgust', 'neutral',
  ];

  // ── Local Simulation ─────────────────────────────────────
  Future<EmotionResult> _analyzeLocally(File audioFile) async {
    await Future.delayed(const Duration(milliseconds: 1500));

    final fileLength = await audioFile.length();
    final pathHash = audioFile.path.hashCode.abs();
    final hash = (fileLength + pathHash).abs();

    final scores = <String, double>{};
    double totalWeight = 0.0;

    for (int i = 0; i < _emotionKeys.length; i++) {
      final key = _emotionKeys[i];
      final weight = ((hash + (i * 17)) % 100) / 100.0;
      scores[key] = weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) totalWeight = 1;

    final allEmotions = scores.map((k, v) => MapEntry(k, v / totalWeight));
    final dominant = allEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);

    return EmotionResult(
      emotion: dominant.key,
      confidence: dominant.value.clamp(0.0, 1.0),
      allEmotions: allEmotions,
      timestamp: DateTime.now(),
      type: 'audio',
    );
  }

  // ── Main entry point ─────────────────────────────────────
  Future<EmotionResult> analyzeAudio(File audioFile) async {
    final clientId = _uuid.v4();
    debugPrint('🎵 Analysing audio locally...');

    final localResult = await _analyzeLocally(audioFile);
    final result = EmotionResult(
      emotion: localResult.emotion,
      confidence: localResult.confidence,
      allEmotions: localResult.allEmotions,
      timestamp: DateTime.now(),
      type: 'audio',
      clientId: clientId,
    );

    // Save locally
    await _timelineService.saveResult(result);

    // Sync to cloud API
    _syncToCloud(result, audioFile, clientId);

    return result;
  }

  void _syncToCloud(EmotionResult result, File audioFile, String clientId) {
    _api.postMultipart(
      '/analysis/audio',
      file: audioFile,
      fileField: 'AudioFile',
      fields: {
        'Request': jsonEncode({
          'client_id': clientId,
          'result': {
            'final_multimodal_emotion': {
              'label': result.emotion,
              'confidence': result.confidence,
              'confidence_percent': result.confidence * 100,
              'category': 'Natural',
            },
            'probabilities': result.allEmotions.entries
                .map((e) => {
                      'label': e.key,
                      'confidence': e.value,
                      'confidence_percent': e.value * 100,
                    })
                .toList(),
          },
        }),
      },
    ).then((response) {
      if (response.isSuccess) debugPrint('🎵 Synced to cloud successfully');
    });
  }
}



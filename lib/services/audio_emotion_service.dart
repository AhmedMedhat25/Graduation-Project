import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class AudioEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    final clientId = _uuid.v4();

    try {
      debugPrint('🎵 Sending audio analysis request (clientId: $clientId)...');

      final postResponse = await _api.postMultipart(
        '/analysis/audio',
        file: audioFile,
        fileField: 'AudioFile',
        fields: {
          'Request': jsonEncode({
            'client_id': clientId,
            'result': {
              'audio_filename': audioFile.path.split(Platform.pathSeparator).last,
            }
          }),
        },
      );

      if (!postResponse.isSuccess) {
        throw Exception(postResponse.message);
      }

      debugPrint('🎵 POST success, polling for result...');
      final resultPayload = await _pollForResult(clientId);

      debugPrint('🎵 Raw result payload keys: ${resultPayload.keys.toList()}');

      final parsed = EmotionResult.fromAudioApi({
        ...resultPayload,
        'client_id': resultPayload['client_id'] ?? clientId,
      });

      final result = EmotionResult(
        emotion: parsed.emotion,
        confidence: parsed.confidence,
        allEmotions: parsed.allEmotions,
        timestamp: parsed.timestamp,
        type: 'audio',
        analysisId: parsed.analysisId,
        clientId: parsed.clientId ?? clientId,
        timeline: parsed.timeline,
      );

      await _timelineService.saveResult(result);
      debugPrint('🎵 Audio analysis complete: ${result.emotion} (${result.confidencePercent}%)');
      return result;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Audio analysis error: $e');
      throw Exception('Failed to analyze audio: $e');
    }
  }

  /// Polls GET /analysis/{clientId} until the result contains actual
  /// multimodal analysis data.
  Future<Map<String, dynamic>> _pollForResult(String clientId) async {
    const maxAttempts = 15;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      // Audio takes longer — wait more on early attempts
      await Future.delayed(Duration(milliseconds: attempt <= 2 ? 3000 : 2500));

      final response = await _api.get('/analysis/$clientId');

      if (!response.isSuccess || response.body is! Map<String, dynamic>) {
        debugPrint('🎵 Attempt $attempt: not ready (status ${response.statusCode})');
        continue;
      }

      final body = response.body as Map<String, dynamic>;

      final payload = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;

      final result = payload['result'] is Map<String, dynamic>
          ? payload['result'] as Map<String, dynamic>
          : payload;

      debugPrint('🎵 Attempt $attempt: result keys = ${result.keys.take(8).toList()}');

      if (_hasAnalysisData(result) || _hasAnalysisData(payload)) {
        return payload;
      }

      debugPrint('🎵 Attempt $attempt: analysis not ready yet...');
    }

    throw Exception(
      'Audio analysis result was not available after $maxAttempts attempts. '
      'The backend may still be processing.',
    );
  }

  bool _hasAnalysisData(Map<String, dynamic> data) {
    return data.containsKey('final_multimodal_emotion') ||
        data.containsKey('audio_emotion') ||
        data.containsKey('transcribed_text') ||
        data.containsKey('combined_final_emotion') ||
        data.containsKey('combined_results') ||
        data.containsKey('probabilities') ||
        data.containsKey('dominant');
  }
}
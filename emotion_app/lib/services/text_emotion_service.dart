import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class TextEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  Future<EmotionResult> analyzeText(String text) async {
    final clientId = _uuid.v4();

    try {
      debugPrint('📝 Sending text analysis request (clientId: $clientId)...');

      final postResponse = await _api.post(
        '/analysis/text',
        body: {
          'client_id': clientId,
          'result': {
            'text': text,
          },
        },
      );

      if (!postResponse.isSuccess) {
        throw Exception(postResponse.message);
      }

      debugPrint('📝 POST success, polling for result...');
      final resultPayload = await _pollForResult(clientId);

      debugPrint('📝 Raw result payload keys: ${resultPayload.keys.toList()}');

      final parsed = EmotionResult.fromTextApi({
        ...resultPayload,
        'client_id': resultPayload['client_id'] ?? clientId,
      });

      final result = EmotionResult(
        emotion: parsed.emotion,
        confidence: parsed.confidence,
        allEmotions: parsed.allEmotions,
        timestamp: parsed.timestamp,
        type: 'text',
        analysisId: parsed.analysisId,
        clientId: parsed.clientId ?? clientId,
        timeline: parsed.timeline,
      );

      await _timelineService.saveResult(result);
      debugPrint('📝 Text analysis complete: ${result.emotion} (${result.confidencePercent}%)');
      return result;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Text analysis error: $e');
      throw Exception('Failed to analyze text: $e');
    }
  }

  /// Polls GET /analysis/{clientId} until the result contains actual
  /// analysis data (not just the raw input text).
  Future<Map<String, dynamic>> _pollForResult(String clientId) async {
    const maxAttempts = 12;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      await Future.delayed(Duration(milliseconds: attempt <= 2 ? 1500 : 2500));

      final response = await _api.get('/analysis/$clientId');

      if (!response.isSuccess || response.body is! Map<String, dynamic>) {
        debugPrint('📝 Attempt $attempt: not ready (status ${response.statusCode})');
        continue;
      }

      final body = response.body as Map<String, dynamic>;

      // Unwrap: the analysis object lives inside body['data']
      final payload = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;

      // The actual analysis result lives inside payload['result']
      final result = payload['result'] is Map<String, dynamic>
          ? payload['result'] as Map<String, dynamic>
          : payload;

      debugPrint('📝 Attempt $attempt: result keys = ${result.keys.take(8).toList()}');

      // Check if the result contains ACTUAL analysis data,
      // not just the raw input. Any of these fields indicate
      // the backend has finished processing.
      if (_hasAnalysisData(result) || _hasAnalysisData(payload)) {
        // Return the full payload (with id, client_id, result nested inside)
        return payload;
      }

      debugPrint('📝 Attempt $attempt: analysis not ready yet...');
    }

    throw Exception(
      'Text analysis result was not available after $maxAttempts attempts. '
      'The backend may still be processing.',
    );
  }

  /// Returns true if the map contains keys that indicate processed analysis data.
  bool _hasAnalysisData(Map<String, dynamic> data) {
    return data.containsKey('combined_final_emotion') ||
        data.containsKey('full_text_analysis') ||
        data.containsKey('combined_results') ||
        data.containsKey('probabilities') ||
        data.containsKey('dominant') ||
        (data.containsKey('emotion') && data['emotion'] is! String?) ||
        data.containsKey('sentences_analysis');
  }
}
import 'package:flutter/foundation.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class TextEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();

  Future<EmotionResult> analyzeText(String text) async {
    try {
      debugPrint('📝 Sending text analysis request...');

      ApiResponse response;

      // 🔥 Try standard format
      try {
        response = await _api.post('/analysis/text', body: {
          'text': text,
        });

        if (!response.isSuccess) {
          throw Exception('Standard format failed');
        }
      } catch (_) {
        // 🔥 Fallback format
        debugPrint('📝 Trying fallback format...');
        response = await _api.post('/analysis/text', body: {
          'client_id': 'emotra-flutter',
          'result': {'text': text},
        });
      }

      // 🔴 Validate response
      if (response.body is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }

      final body = response.body as Map<String, dynamic>;

      // 🔥 Safe unwrap
      final resultData =
      (body['data'] is Map<String, dynamic>)
          ? body['data']
          : (body['result'] is Map<String, dynamic>)
          ? body['result']
          : body;

      debugPrint('📝 Parsed raw data: $resultData');

      // 🔥 Parse safely using model
      final parsed = EmotionResult.fromTextApiV2(resultData);

      // 🔥 Extract analysisId if exists
      int? analysisId;

      if (body['data'] is Map) {
        final data = body['data'];
        analysisId = data['analysis_v2_id'] ??
            data['id'];
      } else {
        analysisId = body['id'];
      }

      final result = EmotionResult(
        emotion: parsed.emotion,
        confidence: parsed.confidence,
        allEmotions: parsed.allEmotions,
        timestamp: parsed.timestamp,
        type: 'text',
        analysisId: analysisId ?? parsed.analysisId,
        timeline: parsed.timeline,
      );

      // 🔥 Save locally
      await _timelineService.saveResult(result);

      debugPrint('📝 Final Emotion: ${result.emotion}');

      return result;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('📝 Text analysis error: $e');
      throw Exception('Failed to analyze text');
    }
  }
}
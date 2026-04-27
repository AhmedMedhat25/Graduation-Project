import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class TextEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();
  final _uuid = const Uuid();

  Future<EmotionResult> analyzeText(String text) async {
    final clientId = _uuid.v4();

    try {
      debugPrint('📝 Sending text analysis request to API...');

      // 1. POST request to API
      final response = await _api.post('/analysis/text', body: {
        'client_id': clientId,
        'result': {'text': text},
      });

      if (!response.isSuccess) {
        throw Exception(response.message);
      }

      // 2. Fetch the actual analysis result via GET using clientId
      debugPrint('📝 Fetching result from API...');
      final getResponse = await _api.get('/analysis/$clientId');

      if (!getResponse.isSuccess || getResponse.body is! Map) {
        throw Exception('Failed to retrieve analysis result from API');
      }

      final body = getResponse.body as Map<String, dynamic>;
      
      // The GET endpoint returns { "data": { ... } }
      final resultData = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;

      // Pass clientId into rawJson so fromTextApiV2 can capture it
      final rawForParsing = <String, dynamic>{
        ...resultData,
        'client_id': clientId,
      };

      final parsed = EmotionResult.fromTextApiV2(rawForParsing);

      // Extract server-assigned analysisId if present
      int? analysisId = _safeInt(resultData['id']) ?? _safeInt(body['id']);

      final result = EmotionResult(
        emotion: parsed.emotion,
        confidence: parsed.confidence,
        allEmotions: parsed.allEmotions,
        timestamp: parsed.timestamp,
        type: 'text',
        analysisId: analysisId ?? parsed.analysisId,
        clientId: clientId,
        timeline: parsed.timeline,
      );

      // Save locally
      await _timelineService.saveResult(result);

      debugPrint('📝 Final API Emotion: ${result.emotion}');

      return result;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('📝 Text analysis error: $e');
      throw Exception('Failed to analyze text via API');
    }
  }

  static int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
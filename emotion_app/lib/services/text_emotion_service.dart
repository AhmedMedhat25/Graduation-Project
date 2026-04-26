import 'package:flutter/foundation.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
//  📝  TEXT EMOTION SERVICE — Real API Analysis
// ============================================================
class TextEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();

  /// Send text to the API for real ML analysis.
  /// The API performs the emotion detection and returns the result.
  Future<EmotionResult> analyzeText(String text) async {
    try {
      final response = await _api.post('/analysis/text', body: {
        'client_id': 'emotra-flutter',
        'result': {
          'text': text,
        },
      });

      debugPrint('📝 Text API response: status=${response.statusCode}, body=${response.body}');

      if (response.isSuccess && response.body != null) {
        final body = response.body;

        if (body is Map<String, dynamic>) {
          // Parse the full API response using the V2 parser
          final result = EmotionResult.fromTextApiV2(body);

          // Save to local timeline if API returned real data
          await _timelineService.saveResult(result);

          return result;
        }
      }

      throw Exception(response.message);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      debugPrint('Text analysis error: $e');
      throw Exception('Failed to analyze text: $e');
    }
  }
}

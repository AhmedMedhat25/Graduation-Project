import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class TextEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  static const String _aiApiUrl = 'https://graduation-project-website-eight.vercel.app/text/emotion/text_model';

  Future<EmotionResult> analyzeText(String text) async {
    final clientId = _uuid.v4();
    
    try {
      debugPrint('📝 Phase 1: Calling AI Microservice (Vercel)...');

      // 1. Get result from AI
      final aiResponse = await _api.postRaw(
        _aiApiUrl,
        body: {'text': text},
      );

      if (!aiResponse.isSuccess) {
        throw Exception('AI Analysis failed: ${aiResponse.message}');
      }

      final aiResult = aiResponse.body as Map<String, dynamic>;
      debugPrint('📝 Phase 1 Success. Combined emotion: ${aiResult['combined_final_emotion']?['label']}');

      // 2. Save result to Main Backend
      debugPrint('📝 Phase 2: Saving result to Main Backend (analysis/text)...');
      final saveResponse = await _api.post(
        '/analysis/text',
        body: {
          'client_id': clientId,
          'result': aiResult,
        },
      );

      if (!saveResponse.isSuccess) {
        debugPrint('⚠️ Save to backend failed, but AI result is valid. Proceeding locally.');
      }

      // 3. Parse and persist locally
      final analysisId = _apiSafeInt(saveResponse.body is Map ? saveResponse.body['data'] : null);
      
      final result = EmotionResult.fromTextApi({
        ...aiResult,
        'id': analysisId,
        'client_id': clientId,
      });

      await _timelineService.saveResult(result);
      debugPrint('📝 Text analysis complete. ID: ${result.analysisId ?? "Local Only"}');
      
      return result;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Text analysis error: $e');
      throw Exception('Failed to analyze text: $e');
    }
  }

  int? _apiSafeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
// 🚨 Typed Exception — replaces generic Exception wrapping
// ============================================================
class TextAnalysisException implements Exception {
  final String message;
  final Object? cause;

  const TextAnalysisException(this.message, {this.cause});

  @override
  String toString() =>
      cause != null
          ? 'TextAnalysisException: $message (caused by: $cause)'
          : 'TextAnalysisException: $message';
}

class TextEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  static const String _aiApiUrl =
      'https://graduation-project-website-eight.vercel.app/text/emotion/text_model';

  Future<EmotionResult> analyzeText(String text) async {
    final clientId = _uuid.v4();

    try {
      debugPrint('📝 Calling AI service...');

      final aiResponse = await _api.postRaw(
        _aiApiUrl,
        body: {'text': text},
      );

      debugPrint('AI STATUS: ${aiResponse.statusCode}');
      debugPrint('AI BODY: ${aiResponse.body}');

      if (!aiResponse.isSuccess) {
        throw TextAnalysisException('AI Analysis failed', cause: aiResponse.message);
      }

      final aiResult = _extractMap(aiResponse.body);

      debugPrint('🧠 Parsed AI Result: $aiResult');

      debugPrint('💾 Saving to backend...');

      final saveResponse = await _api.post(
        '/analysis/text',
        body: {
          'client_id': clientId,
          'result': aiResult,
        },
      );

      debugPrint('SAVE STATUS: ${saveResponse.statusCode}');
      debugPrint('SAVE BODY: ${saveResponse.body}');

      // ✅ FIXED analysisId extraction
      final analysisId = _safeInt(
        saveResponse.body is Map
            ? (saveResponse.body['data'] is Map
            ? saveResponse.body['data']['id']
            : saveResponse.body['data'])
            : null,
      );

      final result = EmotionResult.fromTextApi({
        ...aiResult,
        'id': analysisId,
        'client_id': clientId,
      });

      if (result.type == 'unknown') {
        throw const TextAnalysisException('Invalid AI response format');
      }

      await _timelineService.saveResult(result);

      return result;
    } on SessionExpiredException {
      rethrow;
    } on TextAnalysisException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('❌ Network error during text analysis: $e');
      throw TextAnalysisException('No internet connection', cause: e);
    } on HandshakeException catch (e) {
      debugPrint('❌ SSL/TLS error during text analysis: $e');
      throw TextAnalysisException('Secure connection failed', cause: e);
    } on HttpException catch (e) {
      debugPrint('❌ HTTP error during text analysis: $e');
      throw TextAnalysisException('HTTP request failed', cause: e);
    } on FormatException catch (e) {
      debugPrint('❌ Response parsing error during text analysis: $e');
      throw TextAnalysisException('Invalid response format', cause: e);
    } catch (e) {
      debugPrint('❌ Unexpected text analysis error: $e');
      throw TextAnalysisException('Unexpected error occurred', cause: e);
    }
  }

  // ✅ Safe JSON extraction
  Map<String, dynamic> _extractMap(dynamic body) {
    if (body is Map<String, dynamic>) return body;

    if (body is Map) return Map<String, dynamic>.from(body);

    throw const TextAnalysisException('Invalid AI response format (not a JSON object)');
  }

  int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
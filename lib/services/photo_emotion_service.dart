import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
//  📸  PHOTO EMOTION SERVICE — Real AI API + Backend sync
// ============================================================
class PhotoAnalysisException implements Exception {
  final String message;
  final Object? cause;

  const PhotoAnalysisException(this.message, {this.cause});

  @override
  String toString() =>
      cause != null
          ? 'PhotoAnalysisException: $message (caused by: $cause)'
          : 'PhotoAnalysisException: $message';
}

class PhotoEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  static const String _aiApiUrl =
      'https://graduation-project-website-eight.vercel.app/image/emotion/image';

  Future<EmotionResult> analyzePhoto(File imageFile) async {
    final clientId = _uuid.v4();

    try {
      // ============================================================
      // 📸 PHASE 1: AI Microservice
      // ============================================================
      debugPrint('📸 Phase 1: Calling AI Image Service...');

      final aiResponse = await _api.postRawMultipart(
        _aiApiUrl,
        file: imageFile,
        fileField: 'file',
      );

      if (!aiResponse.isSuccess) {
        final body = aiResponse.body;
        final detail = body is Map
            ? (body['detail'] ?? body['message'] ?? body.toString())
            : body?.toString() ?? 'Unknown error';
        debugPrint('❌ AI Image error: $detail');
        throw PhotoAnalysisException('AI Image Analysis failed', cause: detail);
      }

      if (aiResponse.body is! Map) {
        throw const PhotoAnalysisException('Invalid AI response format');
      }

      final aiResult = Map<String, dynamic>.from(aiResponse.body as Map);

      debugPrint(
        '📸 Phase 1 Success. Dominant: '
        '${aiResult['combined_final_emotion']?['label'] ?? aiResult['dominant']?['label']}',
      );

      // ============================================================
      // 💾 PHASE 2: Save to Main Backend (multipart/form-data)
      // ============================================================
      debugPrint('📸 Phase 2: Saving to backend via multipart...');

      final saveResponse = await _api.postMultipart(
        '/analysis/image',
        file: imageFile,
        fileField: 'ImageFile',
        fields: {
          'client_id': clientId,
          'Request': jsonEncode({
            'client_id': clientId,
            'result': aiResult,
          }),
        },
      );

      if (!saveResponse.isSuccess) {
        debugPrint(
          '⚠️ Backend save failed (continuing locally): '
          '${saveResponse.message}',
        );
      }

      final analysisId = saveResponse.isSuccess
          ? _safeInt(
              saveResponse.body is Map
                  ? (saveResponse.body as Map)['data']
                  : null,
            )
          : null;

      // ============================================================
      // 📱 PHASE 3: Parse + Local Save
      // ============================================================
      final result = EmotionResult.fromPhotoApi({
        ...aiResult,
        'id': analysisId,
        'client_id': clientId,
      });

      if (result.type == 'unknown') {
        throw const PhotoAnalysisException('Failed to parse image analysis result');
      }

      await _timelineService.saveResult(result);

      debugPrint(
        '📸 Photo analysis complete. '
        'ID: ${result.analysisId ?? "Local Only"}',
      );

      return result;
    } on SessionExpiredException {
      rethrow;
    } on PhotoAnalysisException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('❌ Network error during photo analysis: $e');
      throw PhotoAnalysisException('No internet connection', cause: e);
    } on HandshakeException catch (e) {
      debugPrint('❌ SSL/TLS error during photo analysis: $e');
      throw PhotoAnalysisException('Secure connection failed', cause: e);
    } on HttpException catch (e) {
      debugPrint('❌ HTTP error during photo analysis: $e');
      throw PhotoAnalysisException('HTTP request failed', cause: e);
    } on FormatException catch (e) {
      debugPrint('❌ Response parsing error during photo analysis: $e');
      throw PhotoAnalysisException('Invalid response format', cause: e);
    } catch (e) {
      debugPrint('❌ Unexpected photo analysis error: $e');
      throw PhotoAnalysisException('Unexpected error occurred', cause: e);
    }
  }

  int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

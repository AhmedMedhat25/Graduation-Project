import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
//  🎥  VIDEO EMOTION SERVICE — Real AI API + Backend sync
// ============================================================
class VideoAnalysisException implements Exception {
  final String message;
  final Object? cause;

  const VideoAnalysisException(this.message, {this.cause});

  @override
  String toString() =>
      cause != null
          ? 'VideoAnalysisException: $message (caused by: $cause)'
          : 'VideoAnalysisException: $message';
}

class VideoEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  static const String _aiApiUrl =
      'https://graduation-project-website-eight.vercel.app/video/emotion/video';

  Future<EmotionResult> analyzeVideo(File videoFile) async {
    final clientId = _uuid.v4();

    try {
      // ============================================================
      // 🎥 PHASE 1: AI Microservice
      // ============================================================
      debugPrint('🎥 Phase 1: Calling AI Video Service...');

      final aiResponse = await _api.postRawMultipart(
        _aiApiUrl,
        file: videoFile,
        fileField: 'file',
      );

      if (!aiResponse.isSuccess) {
        final body = aiResponse.body;
        final detail = body is Map
            ? (body['detail'] ?? body['message'] ?? body.toString())
            : body?.toString() ?? 'Unknown error';
        debugPrint('❌ AI Video error: $detail');
        throw VideoAnalysisException('AI Video Analysis failed', cause: detail);
      }

      if (aiResponse.body is! Map) {
        throw const VideoAnalysisException('Invalid AI response format');
      }

      final aiResult = Map<String, dynamic>.from(aiResponse.body as Map);

      debugPrint(
        '🎥 Phase 1 Success. Dominant: '
        '${aiResult['combined_final_emotion']?['label'] ?? aiResult['dominant']?['label']}',
      );

      // ============================================================
      // 💾 PHASE 2: Save to Main Backend (multipart/form-data)
      // ============================================================
      debugPrint('🎥 Phase 2: Saving to backend via multipart...');

      final saveResponse = await _api.postMultipart(
        '/analysis/video',
        file: videoFile,
        fileField: 'VideoFile',
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
      final result = EmotionResult.fromVideoApi({
        ...aiResult,
        'id': analysisId,
        'client_id': clientId,
      });

      if (result.type == 'unknown') {
        throw const VideoAnalysisException('Failed to parse video analysis result');
      }

      await _timelineService.saveResult(result);

      debugPrint(
        '🎥 Video analysis complete. '
        'ID: ${result.analysisId ?? "Local Only"}',
      );

      return result;
    } on SessionExpiredException {
      rethrow;
    } on VideoAnalysisException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('❌ Network error during video analysis: $e');
      throw VideoAnalysisException('No internet connection', cause: e);
    } on HandshakeException catch (e) {
      debugPrint('❌ SSL/TLS error during video analysis: $e');
      throw VideoAnalysisException('Secure connection failed', cause: e);
    } on HttpException catch (e) {
      debugPrint('❌ HTTP error during video analysis: $e');
      throw VideoAnalysisException('HTTP request failed', cause: e);
    } on FormatException catch (e) {
      debugPrint('❌ Response parsing error during video analysis: $e');
      throw VideoAnalysisException('Invalid response format', cause: e);
    } catch (e) {
      debugPrint('❌ Unexpected video analysis error: $e');
      throw VideoAnalysisException('Unexpected error occurred', cause: e);
    }
  }

  int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

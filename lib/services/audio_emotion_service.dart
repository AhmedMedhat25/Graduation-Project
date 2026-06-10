import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
// 🚨 Typed Exception — replaces generic Exception wrapping
// ============================================================
class AudioAnalysisException implements Exception {
  final String message;
  final Object? cause;

  const AudioAnalysisException(this.message, {this.cause});

  @override
  String toString() =>
      cause != null
          ? 'AudioAnalysisException: $message (caused by: $cause)'
          : 'AudioAnalysisException: $message';
}

class AudioEmotionService {
  final ApiClient _api = ApiClient();
  final TimelineService _timelineService = TimelineService();
  final Uuid _uuid = const Uuid();

  /// Pulled from environment/config — not hardcoded in source.
  /// Set this via --dart-define or a config class per flavour.
  static final String _aiApiUrl = const String.fromEnvironment(
    'AUDIO_EMOTION_API_URL',
    defaultValue:
    'https://graduation-project-website-eight.vercel.app/audio/emotion/audio_model',
  );

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    final clientId = _uuid.v4();

    try {
      // ============================================================
      // 🎵 PHASE 1: AI Microservice (Vercel)
      // ============================================================
      debugPrint('🎵 Phase 1: Calling AI Audio Service...');

      final aiResponse = await _api.postRawMultipart(
        _aiApiUrl,
        file: audioFile,
        fileField: 'file',
      );

      if (!aiResponse.isSuccess) {
        final body = aiResponse.body;
        final detail = body is Map
            ? (body['detail'] ?? body['message'] ?? body.toString())
            : body?.toString() ?? 'Unknown error';
        debugPrint('❌ AI Audio 500 detail: $detail');
        throw AudioAnalysisException(
          'AI Audio Analysis failed',
          cause: detail,
        );
      }

      if (aiResponse.body is! Map) {
        throw const AudioAnalysisException('Invalid AI response format');
      }

      final aiResult = Map<String, dynamic>.from(aiResponse.body as Map);

      debugPrint(
        '🎵 Phase 1 Success. Final emotion: '
            '${aiResult['final_multimodal_emotion']?['label']}',
      );

      // ============================================================
      // 💾 PHASE 2: Save to Main Backend
      // ============================================================
      debugPrint('🎵 Phase 2: Saving to backend...');

      final saveResponse = await _api.post(
        '/analysis/audio',
        body: {
          'client_id': clientId,
          'result': aiResult,
        },
      );

      if (!saveResponse.isSuccess) {
        // Non-fatal: log with reason but continue with local save.
        // Report to your crash reporter here in production (e.g. Sentry).
        debugPrint(
          '⚠️ Backend save failed (continuing locally): '
              '${saveResponse.message}',
        );
      }

      // Only extract analysisId when save actually succeeded.
      final analysisId =
      saveResponse.isSuccess
          ? _safeInt(
        saveResponse.body is Map
            ? (saveResponse.body as Map)['data']
            : null,
      )
          : null;

      // ============================================================
      // 📱 PHASE 3: Parse + Local Save
      // ============================================================
      final result = EmotionResult.fromAudioApi({
        ...aiResult,
        'id': analysisId,
        'client_id': clientId,
      });

      if (result.type == 'unknown') {
        throw const AudioAnalysisException(
          'Failed to parse audio analysis result',
        );
      }

      await _timelineService.saveResult(result);

      debugPrint(
        '🎵 Audio analysis complete. '
            'ID: ${result.analysisId ?? "Local Only"}',
      );

      return result;

      // ============================================================
      // 🚨 Typed catch blocks — preserve original exception types
      // ============================================================
    } on SessionExpiredException {
      rethrow;
    } on AudioAnalysisException {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('❌ Network error during audio analysis: $e');
      throw AudioAnalysisException('No internet connection', cause: e);
    } on HandshakeException catch (e) {
      debugPrint('❌ SSL/TLS error during audio analysis: $e');
      throw AudioAnalysisException('Secure connection failed', cause: e);
    } on HttpException catch (e) {
      debugPrint('❌ HTTP error during audio analysis: $e');
      throw AudioAnalysisException('HTTP request failed', cause: e);
    } on FormatException catch (e) {
      debugPrint('❌ Response parsing error during audio analysis: $e');
      throw AudioAnalysisException('Invalid response format', cause: e);
    } catch (e) {
      debugPrint('❌ Unexpected audio analysis error: $e');
      throw AudioAnalysisException('Unexpected error occurred', cause: e);
    }
  }

  // ================= SAFE INT =================

  int? _safeInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
//  🎵  AUDIO EMOTION SERVICE — Real API Analysis
// ============================================================
class AudioEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();
  final _uuid = const Uuid();

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    try {
      // ── Step 1: Run ML analysis ──────────────────────────
      // FIX: Request field used to send only { client_id }
      // The ML endpoint only needs the audio file — no extra fields
      final analysisResponse = await _api.postMultipart(
        '/analysis/audio',
        file: audioFile,
        fileField: 'AudioFile',
      );

      debugPrint('🎵 Audio API response: status=${analysisResponse.statusCode}, body=${analysisResponse.body}');

      if (!analysisResponse.isSuccess || analysisResponse.body == null) {
        throw Exception(analysisResponse.message);
      }

      final analysisBody = analysisResponse.body as Map<String, dynamic>;

      // ── Step 2: Save to v2 API ───────────────────────────
      // FIX: was never saving to cloud — history page was always empty
      final clientId = _uuid.v4();
      final saveResponse = await _api.postMultipart(
        '/v2/analysis/audio',
        file: audioFile,
        fileField: 'AudioFile',
        fields: {
          'Request': jsonEncode({
            'client_id': clientId,
            'result': analysisBody,
          }),
        },
      );

      int? analysisId;
      if (saveResponse.isSuccess && saveResponse.body != null) {
        analysisId = saveResponse.body['data'] as int?;
        debugPrint('🎵 Saved to cloud with id=$analysisId');
      }

      // ── Step 3: Parse result ─────────────────────────────
      final result = EmotionResult.fromAudioApiV2({
        ...analysisBody,
        if (analysisId != null) 'id': analysisId,
      });

      // ── Step 4: Save to local timeline ───────────────────
      await _timelineService.saveResult(result);

      return result;

    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      debugPrint('Audio analysis error: $e');
      throw Exception('Failed to analyze audio: $e');
    }
  }
}

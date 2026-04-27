import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class AudioEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();
  final _uuid = const Uuid();

  Future<EmotionResult> analyzeAudio(File audioFile) async {
    final clientId = _uuid.v4();

    try {
      debugPrint('🎵 Starting audio analysis...');

      // ── Single Request: Analyze + Save ────────────────────
      final response = await _api.postMultipart(
        '/analysis/audio',
        file: audioFile,
        fileField: 'AudioFile',
        fields: {
          'Request': jsonEncode({
            'client_id': clientId,
            'save': true,
          }),
        },
      );

      if (!response.isSuccess || response.body is! Map) {
        throw Exception(response.message);
      }

      final body = response.body as Map<String, dynamic>;

      // ── Extract Analysis ID safely ────────────────────────
      int? analysisId;
      final data = body['data'];

      if (data is Map<String, dynamic>) {
        analysisId = data['analysis_v2_id'] ?? data['id'];
      } else if (data is int) {
        analysisId = data;
      }

      // ── Build Result ──────────────────────────────────────
      final result = EmotionResult.fromAudioApiV2({
        ...body,
        if (analysisId != null) 'id': analysisId,
      });

      // ── Save Locally (fail-safe) ──────────────────────────
      try {
        await _timelineService.saveResult(result);
      } catch (e) {
        debugPrint('⚠️ Local save failed: $e');
      }

      debugPrint('🎵 Audio analysis complete: ${result.emotion}');
      return result;

    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('🎵 Audio analysis error: $e');
      throw Exception('Failed to analyze audio');
    }
  }
}

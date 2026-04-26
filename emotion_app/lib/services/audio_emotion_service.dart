import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

// ============================================================
//  🎵  AUDIO EMOTION SERVICE — Real API Analysis
// ============================================================
class AudioEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();

  /// Send audio file to the API for real ML analysis.
  /// The API performs the emotion detection and returns the result.
  Future<EmotionResult> analyzeAudio(File audioFile) async {
    try {
      final requestJson = jsonEncode({
        'client_id': 'emotra-flutter',
      });

      final response = await _api.postMultipart(
        '/analysis/audio',
        file: audioFile,
        fileField: 'AudioFile',
        fields: {
          'Request': requestJson,
        },
      );

      debugPrint('🎵 Audio API response: status=${response.statusCode}, body=${response.body}');

      if (response.isSuccess && response.body != null) {
        final body = response.body;

        if (body is Map<String, dynamic>) {
          // Parse the full API response using the V2 parser
          final result = EmotionResult.fromAudioApiV2(body);

          await _timelineService.saveResult(result);

          return result;
        }
      }

      throw Exception(response.message);
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      if (e is SessionExpiredException) rethrow;
      debugPrint('Audio analysis error: $e');
      throw Exception('Failed to analyze audio: $e');
    }
  }
}

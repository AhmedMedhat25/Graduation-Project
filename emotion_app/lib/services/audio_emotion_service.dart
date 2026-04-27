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
      debugPrint('🎵 Sending audio analysis request to API...');

      // 1. POST request to API
      final response = await _api.postMultipart(
        '/analysis/audio',
        file: audioFile,
        fileField: 'AudioFile',
        fields: {
          'Request': jsonEncode({
            'client_id': clientId,
          }),
        },
      );

      if (!response.isSuccess) {
        throw Exception(response.message);
      }

      // 2. Fetch the actual analysis result via GET using clientId
      debugPrint('🎵 Fetching result from API...');
      
      // Delay briefly to allow backend processing to complete if it is async
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final getResponse = await _api.get('/analysis/$clientId');

      if (!getResponse.isSuccess || getResponse.body is! Map) {
        throw Exception('Failed to retrieve analysis result from API');
      }

      final body = getResponse.body as Map<String, dynamic>;
      
      // The GET endpoint returns { "data": { ... } }
      final resultData = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;

      // Pass clientId into rawJson so fromAudioApiV2 can capture it
      final rawForParsing = <String, dynamic>{
        ...resultData,
        'client_id': clientId,
      };

      final parsed = EmotionResult.fromAudioApiV2(rawForParsing);

      // Extract server-assigned analysisId if present
      int? analysisId = _safeInt(resultData['id']) ?? _safeInt(body['id']);

      final result = EmotionResult(
        emotion: parsed.emotion,
        confidence: parsed.confidence,
        allEmotions: parsed.allEmotions,
        timestamp: parsed.timestamp,
        type: 'audio',
        analysisId: analysisId ?? parsed.analysisId,
        clientId: clientId,
        timeline: parsed.timeline,
      );

      // Save locally
      await _timelineService.saveResult(result);

      debugPrint('🎵 Final API Emotion: ${result.emotion}');

      return result;
    } on SessionExpiredException {
      rethrow;
    } catch (e) {
      debugPrint('🎵 Audio analysis error: $e');
      throw Exception('Failed to analyze audio via API');
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



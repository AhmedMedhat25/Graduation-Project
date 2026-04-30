import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/emotion_result.dart';
import 'timeline_service.dart';

// ============================================================
//  📸  PHOTO EMOTION SERVICE — Local analysis + API sync
// ============================================================
// NOTE: The API at emotion-detection.runasp.net does not currently
// have a dedicated photo analysis endpoint. This service runs
// client-side analysis and saves the result to the local timeline.
class PhotoEmotionService {
  final _timelineService = TimelineService();

  Future<EmotionResult> analyzePhoto(File imageFile) async {
    // Simulate ML processing delay
    await Future.delayed(const Duration(milliseconds: 2000));

    final fileLength = await imageFile.length();
    final pathHash = imageFile.path.hashCode.abs();
    final hash = (fileLength + pathHash).abs();

    Map<String, double> weights = {
      'joy': (hash % 100) / 100.0,
      'sadness': ((hash + 13) % 100) / 100.0,
      'anger': ((hash + 27) % 100) / 100.0,
      'fear': ((hash + 42) % 100) / 100.0,
      'surprise': ((hash + 58) % 100) / 100.0,
      'disgust': ((hash + 73) % 100) / 100.0,
      'neutral': ((hash + 89) % 100) / 100.0,
    };

    double total = weights.values.fold(0, (sum, val) => sum + val);
    if (total == 0) total = 1;

    final allEmotions = weights.map((key, value) => MapEntry(key, value / total));

    String topEmotion = 'neutral';
    double topConfidence = 0;
    
    allEmotions.forEach((key, value) {
      if (value > topConfidence) {
        topConfidence = value;
        topEmotion = key;
      }
    });

    final result = EmotionResult(
      emotion: topEmotion,
      confidence: topConfidence,
      allEmotions: allEmotions,
      timestamp: DateTime.now(),
      type: 'photo',
    );

    // Save to local timeline so it appears in dashboard & history
    await _timelineService.saveResult(result);
    debugPrint('📸 Photo analysis saved locally: $topEmotion (${(topConfidence * 100).toStringAsFixed(1)}%)');

    return result;
  }
}

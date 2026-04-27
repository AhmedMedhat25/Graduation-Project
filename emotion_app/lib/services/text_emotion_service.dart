import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/emotion_result.dart';
import 'api_client.dart';
import 'timeline_service.dart';

class TextEmotionService {
  final _api = ApiClient();
  final _timelineService = TimelineService();
  final _uuid = const Uuid();

  // ── Lexicon ──────────────────────────────────────────────
  static const Map<String, Map<String, double>> _lexicon = {
    // Joy / Happy
    'happy': {'joy': 0.9}, 'happiness': {'joy': 0.9},
    'joy': {'joy': 0.95}, 'joyful': {'joy': 0.95},
    'excited': {'joy': 0.85, 'surprise': 0.1},
    'great': {'joy': 0.75}, 'wonderful': {'joy': 0.85},
    'amazing': {'joy': 0.85}, 'fantastic': {'joy': 0.9},
    'love': {'joy': 0.8}, 'loved': {'joy': 0.8},
    // Sadness
    'sad': {'sadness': 0.9}, 'sadness': {'sadness': 0.9},
    'unhappy': {'sadness': 0.8}, 'cry': {'sadness': 0.85},
    'depressed': {'sadness': 0.9}, 'lonely': {'sadness': 0.8},
    'miserable': {'sadness': 0.9}, 'heartbroken': {'sadness': 0.9},
    // Anger
    'angry': {'anger': 0.9}, 'anger': {'anger': 0.9},
    'furious': {'anger': 0.95}, 'rage': {'anger': 0.95},
    'mad': {'anger': 0.85}, 'hate': {'anger': 0.8},
    'annoyed': {'anger': 0.7}, 'frustrated': {'anger': 0.75},
    // Fear
    'fear': {'fear': 0.9}, 'scared': {'fear': 0.9},
    'afraid': {'fear': 0.9}, 'terrified': {'fear': 0.95},
    'anxious': {'fear': 0.8}, 'panic': {'fear': 0.9},
    // Surprise
    'surprised': {'surprise': 0.85}, 'surprise': {'surprise': 0.85},
    'shocked': {'surprise': 0.85}, 'unexpected': {'surprise': 0.7},
    'wow': {'surprise': 0.8, 'joy': 0.2},
    // Disgust
    'disgusted': {'disgust': 0.9}, 'disgust': {'disgust': 0.9},
    'gross': {'disgust': 0.85}, 'nasty': {'disgust': 0.8},
    // Negation helpers
    'not': {}, 'never': {}, 'no': {}, "don't": {}, "doesn't": {},
  };

  static const List<String> _emotionKeys = [
    'joy', 'sadness', 'anger', 'fear', 'surprise', 'disgust', 'neutral',
  ];

  // ── Local analysis ───────────────────────────────────────
  EmotionResult _analyzeLocally(String text) {
    final words = text
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final scores = <String, double>{for (final e in _emotionKeys) e: 0.0};
    double totalWeight = 0.0;
    bool negated = false;

    for (int i = 0; i < words.length; i++) {
      final w = words[i];
      if ({'not', 'never', 'no', "don't", "doesn't"}.contains(w)) {
        negated = true; continue;
      }
      final entry = _lexicon[w];
      if (entry != null && entry.isNotEmpty) {
        for (final kv in entry.entries) {
          final targetKey = negated ? _flipEmotion(kv.key) : kv.key;
          scores[targetKey] = (scores[targetKey] ?? 0) + kv.value;
          totalWeight += kv.value;
        }
        negated = false;
      } else if (negated && i > 0) negated = false;
    }

    if (totalWeight == 0) {
      final empty = EmotionResult.empty();
      return EmotionResult(
        emotion: empty.emotion,
        confidence: empty.confidence,
        allEmotions: empty.allEmotions,
        timestamp: empty.timestamp,
        type: 'text',
      );
    }

    final allEmotions = scores.map((k, v) => MapEntry(k, v / totalWeight));
    final dominant = allEmotions.entries.reduce((a, b) => a.value > b.value ? a : b);

    return EmotionResult(
      emotion: dominant.key,
      confidence: dominant.value,
      allEmotions: allEmotions,
      timestamp: DateTime.now(),
      type: 'text',
    );
  }

  String _flipEmotion(String e) {
    const map = {'joy': 'sadness', 'sadness': 'joy', 'anger': 'fear', 'fear': 'neutral'};
    return map[e] ?? 'neutral';
  }

  // ── Main entry point ─────────────────────────────────────
  Future<EmotionResult> analyzeText(String text) async {
    final clientId = _uuid.v4();
    debugPrint('📝 Analysing text locally...');

    final localResult = _analyzeLocally(text);
    final result = EmotionResult(
      emotion: localResult.emotion,
      confidence: localResult.confidence,
      allEmotions: localResult.allEmotions,
      timestamp: DateTime.now(),
      type: 'text',
      clientId: clientId,
    );

    // Save locally
    await _timelineService.saveResult(result);

    // Sync to cloud API
    _syncToCloud(result, text, clientId);

    return result;
  }

  void _syncToCloud(EmotionResult result, String text, String clientId) {
    _api.post('/analysis/text', body: {
      'client_id': clientId,
      'result': {
        'text': text,
        'combined_final_emotion': {
          'label': result.emotion,
          'confidence': result.confidence,
          'confidence_percent': result.confidence * 100,
          'category': 'Natural',
        },
        'combined_results': result.allEmotions.entries
            .map((e) => {
                  'label': e.key,
                  'confidence': e.value,
                  'confidence_percent': e.value * 100,
                })
            .toList(),
      },
    }).then((response) {
      if (response.isSuccess) debugPrint('📝 Synced to cloud successfully');
    });
  }
}
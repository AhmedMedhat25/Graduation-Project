import 'emotion_result.dart';

class QuotaTypeStatus {
  final double used;
  final double limit;
  final double remaining;
  final bool isBlocked;

  const QuotaTypeStatus({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.isBlocked,
  });

  factory QuotaTypeStatus.fromJson(Map<String, dynamic> json) {
    return QuotaTypeStatus(
      used: _toDouble(json['used']),
      limit: _toDouble(json['limit']),
      remaining: _toDouble(json['remaining']),
      isBlocked: json['is_blocked'] == true,
    );
  }

  double get usedPercent {
    if (limit <= 0) return 0.0;
    return (used / limit).clamp(0.0, 1.0);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class QuotaStatus {
  final DateTime weekStartDate;
  final QuotaTypeStatus text;
  final QuotaTypeStatus audio;
  final QuotaTypeStatus video;
  final QuotaTypeStatus image;

  const QuotaStatus({
    required this.weekStartDate,
    required this.text,
    required this.audio,
    required this.video,
    required this.image,
  });

  factory QuotaStatus.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> asMap(dynamic value) {
      if (value is Map) return Map<String, dynamic>.from(value);
      return const {};
    }

    final rawWeekStart = json['week_start_date']?.toString();
    final parsedWeekStart = DateTime.tryParse(rawWeekStart ?? '');

    return QuotaStatus(
      weekStartDate: parsedWeekStart ?? EmotionResult.cairoNow(),
      text: QuotaTypeStatus.fromJson(asMap(json['text'])),
      audio: QuotaTypeStatus.fromJson(asMap(json['audio'])),
      video: QuotaTypeStatus.fromJson(asMap(json['video'])),
      image: QuotaTypeStatus.fromJson(asMap(json['image'])),
    );
  }

  QuotaTypeStatus forType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return text;
      case 'audio':
        return audio;
      case 'video':
        return video;
      case 'image':
      case 'photo':
        return image;
      default:
        throw ArgumentError('Unknown quota type: $type');
    }
  }

  QuotaTypeStatus? tryForType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return text;
      case 'audio':
        return audio;
      case 'video':
        return video;
      case 'image':
      case 'photo':
        return image;
      default:
        return null;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';
import '../models/emotion_result.dart';

// ── Emotion Icon Helper ──────────────────────────────────────
String emotionEmoji(String emotion) {
  const map = {
    'happy': '😊', 'joy': '😊',
    'sad': '😢', 'sadness': '😢',
    'angry': '😠', 'anger': '😠',
    'fearful': '😨', 'fear': '😨',
    'surprised': '😲', 'surprise': '😲',
    'disgusted': '🤢', 'disgust': '🤢',
    'neutral': '😐',
  };
  return map[emotion.toLowerCase()] ?? '😐';
}

Color emotionColor(String emotion) {
  final map = {
    'happy': AppColors.happy, 'joy': AppColors.happy,
    'sad': AppColors.sad, 'sadness': AppColors.sad,
    'angry': AppColors.angry, 'anger': AppColors.angry,
    'fearful': AppColors.fearful, 'fear': AppColors.fearful,
    'surprised': AppColors.surprised, 'surprise': AppColors.surprised,
    'disgusted': AppColors.disgusted, 'disgust': AppColors.disgusted,
    'neutral': AppColors.neutral,
  };
  return map[emotion.toLowerCase()] ?? AppColors.neutral;
}

// ── Snackbar Helper ──────────────────────────────────────────
void showAppSnackbar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      duration: Duration(seconds: isError ? 4 : 2),
    ),
  );
}

// ── Emotion Result Card ──────────────────────────────────────
class EmotionResultCard extends StatelessWidget {
  final EmotionResult result;
  const EmotionResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = emotionColor(result.emotion);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(emotionEmoji(result.emotion),
              style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            result.emotion.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(result.confidence * 100).toStringAsFixed(1)}% confidence',
            style: TextStyle(color: AppColors.textMid, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ...result.allEmotions.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        e.key,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMid),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.value,
                          backgroundColor:
                              AppColors.cardBorder,
                          valueColor: AlwaysStoppedAnimation(
                              emotionColor(e.key)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${(e.value * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

// ── Primary Button ───────────────────────────────────────────
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap?.call();
              },
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(label),
                ],
              ),
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionHeader({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textLight)),
        ],
      ],
    );
  }
}

// ── Timeline Entry Widget ────────────────────────────────────
class TimelineEntryWidget extends StatelessWidget {
  final EmotionResult result;
  const TimelineEntryWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final color = emotionColor(result.emotion);
    final typeIcon = {
      'text': Icons.text_fields_rounded,
      'audio': Icons.mic_rounded,
      'photo': Icons.photo_camera_rounded,
      'video': Icons.videocam_rounded,
    }[result.type] ?? Icons.analytics_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emotionEmoji(result.emotion),
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.emotion.toUpperCase(),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(typeIcon, size: 16, color: AppColors.textLight),
              const SizedBox(height: 4),
              Text(
                _formatTime(result.timestamp),
                style: TextStyle(
                    fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}

// ── Animated Empty State ─────────────────────────────────────
class AnimatedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AnimatedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cardBorder.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.textLight),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1.0, end: 1.06, duration: 1800.ms, curve: Curves.easeInOut),
          const SizedBox(height: 16),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textDark)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
        ],
      ),
    )
        .animate(delay: 150.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// ── Error Banner (inline) ────────────────────────────────────
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).shakeX(hz: 2, amount: 2, duration: 400.ms);
  }
}

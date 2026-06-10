import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme.dart';
import '../models/emotion_result.dart';
import '../models/quota_status.dart';

/// ─────────────────────────────────────────────────────────
/// Emotion Helpers
/// ─────────────────────────────────────────────────────────

String emotionEmoji(String emotion) {
  const map = {
    'happy': '😊',
    'joy': '😊',
    'sad': '😢',
    'sadness': '😢',
    'angry': '😠',
    'anger': '😠',
    'fearful': '😨',
    'fear': '😨',
    'surprised': '😲',
    'surprise': '😲',
    'disgusted': '🤢',
    'disgust': '🤢',
    'neutral': '😐',
  };
  return map[emotion.toLowerCase()] ?? '😐';
}

Color emotionColor(String emotion) {
  final map = {
    'happy': AppColors.happy,
    'joy': AppColors.happy,
    'sad': AppColors.sad,
    'sadness': AppColors.sad,
    'angry': AppColors.angry,
    'anger': AppColors.angry,
    'fearful': AppColors.fearful,
    'fear': AppColors.fearful,
    'surprised': AppColors.surprised,
    'surprise': AppColors.surprised,
    'disgusted': AppColors.disgusted,
    'disgust': AppColors.disgusted,
    'neutral': AppColors.neutral,
  };
  return map[emotion.toLowerCase()] ?? AppColors.neutral;
}

String formatEmotionLabel(String emotion) {
  if (emotion.isEmpty) return 'Neutral';
  return emotion[0].toUpperCase() + emotion.substring(1).toLowerCase();
}

/// ─────────────────────────────────────────────────────────
/// Snackbar Helper
/// ─────────────────────────────────────────────────────────

void showAppSnackbar(
    BuildContext context,
    String message, {
      bool isError = false,
    }) {
  final background = isError ? AppColors.error : AppColors.success;
  final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;

  ScaffoldMessenger.of(context).removeCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: background,
      elevation: 0,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      duration: Duration(seconds: isError ? 4 : 2),
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// ─────────────────────────────────────────────────────────
/// Premium Surface Card
/// ─────────────────────────────────────────────────────────

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? color;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// Emotion Result Card — Horizontal Bar Chart Design
/// ─────────────────────────────────────────────────────────

class EmotionResultCard extends StatelessWidget {
  final EmotionResult result;

  const EmotionResultCard({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final dominantColor = emotionColor(result.emotion);

    // Sort emotions by confidence descending
    final sorted = result.allEmotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: Emoji + Dominant label ──
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: dominantColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    emotionEmoji(result.emotion),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatEmotionLabel(result.emotion),
                      style: TextStyle(
                        color: dominantColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: dominantColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: dominantColor.withValues(alpha: 0.18)),
                      ),
                      child: Text(
                        '${(result.confidence * 100).toStringAsFixed(1)}% confidence',
                        style: TextStyle(
                          color: dominantColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Legend
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dominantColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Emotion\nBreakdown',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Horizontal Bar Chart ──
          ...sorted.asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
            final entry = mapEntry.value;
            final barColor = emotionColor(entry.key);
            final percent = entry.value * 100;
            final isDominant =
                entry.key.toLowerCase() == result.emotion.toLowerCase();

            return Padding(
              padding:
                  EdgeInsets.only(bottom: index < sorted.length - 1 ? 10 : 0),
              child: Row(
                children: [
                  // Emotion label — fixed width
                  SizedBox(
                    width: 62,
                    child: Text(
                      formatEmotionLabel(entry.key),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isDominant ? FontWeight.w700 : FontWeight.w500,
                        color: isDominant
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Color dot
                  Container(
                    width: isDominant ? 14 : 10,
                    height: isDominant ? 14 : 10,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Bar — uses Expanded to fill remaining space
                  Expanded(
                    child: Container(
                      height: isDominant ? 20 : 14,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (entry.value).clamp(0.03, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: isDominant
                                ? [
                                    BoxShadow(
                                      color: barColor.withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Percentage — fixed width
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${percent.toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isDominant ? FontWeight.w700 : FontWeight.w600,
                        color: isDominant ? barColor : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}

/// ─────────────────────────────────────────────────────────
/// Primary Button
/// ─────────────────────────────────────────────────────────

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
    final disabled = loading || onTap == null;

    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: disabled
              ? null
              : () {
            HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Ink(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: disabled
                  ? LinearGradient(
                colors: [
                  AppColors.border,
                  AppColors.border,
                ],
              )
                  : AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// Section Header
/// ─────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// Timeline Entry Widget
/// ─────────────────────────────────────────────────────────

class TimelineEntryWidget extends StatelessWidget {
  final EmotionResult result;
  final VoidCallback? onDelete;

  const TimelineEntryWidget({
    super.key,
    required this.result,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = emotionColor(result.emotion);
    final typeIcon = {
      'text': Icons.text_fields_rounded,
      'audio': Icons.mic_rounded,
      'photo': Icons.photo_camera_rounded,
      'video': Icons.videocam_rounded,
    }[result.type] ??
        Icons.analytics_rounded;

    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Emotion avatar ──────────────────────────────
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  emotionEmoji(result.emotion),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // ── Main content ─────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emotion label + timestamp row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          formatEmotionLabel(result.emotion),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(result.timestamp),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Confidence
                  Text(
                    '${(result.confidence * 100).toStringAsFixed(0)}% confidence',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // Summary text (history items only)
                  if (result.summaryText != null &&
                      result.summaryText!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      result.summaryText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // Type badge + delete button row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              typeIcon,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              result.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Visible delete button
                      if (onDelete != null)
                        GestureDetector(
                          onTap: () => _confirmDelete(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                              color: AppColors.error.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideX(begin: 0.03, end: 0, duration: 350.ms);
  }

  void _confirmDelete(BuildContext context) {
    if (onDelete == null) return;

    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text('Delete Analysis?'),
        content: const Text('This record will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.toUtc());

    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// ─────────────────────────────────────────────────────────
/// Animated Empty State
/// ─────────────────────────────────────────────────────────


class AnimatedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AnimatedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Icon(
                icon,
                size: 38,
                color: AppColors.textMuted,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
              begin: 1,
              end: 1.05,
              duration: 1800.ms,
              curve: Curves.easeInOut,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: actionLabel!,
                  onTap: onAction,
                  icon: Icons.add_rounded,
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate(delay: 120.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.12, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

/// ─────────────────────────────────────────────────────────
/// Error Banner
/// ─────────────────────────────────────────────────────────

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onRetry,
                borderRadius: BorderRadius.circular(10),
                child: Ink(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 280.ms)
        .shakeX(hz: 2, amount: 2, duration: 360.ms);
  }
}

/// ─────────────────────────────────────────────────────────
/// Shared Analysis Widgets (extracted from analysis pages)
/// ─────────────────────────────────────────────────────────

/// Loading panel shown during emotion analysis with shimmer text
class AnalysisLoadingPanel extends StatelessWidget {
  final String text;

  const AnalysisLoadingPanel({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            )
                .animate(key: ValueKey(text))
                .fadeIn(duration: 250.ms)
                .shimmer(duration: 1100.ms),
          ),
        ],
      ),
    );
  }
}

/// Status badge pill (e.g. "Live API", "Visual Analysis")
class StatusBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const StatusBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Metadata pill showing icon + label (e.g. "120 chars", "Ready to analyze")
class MetaPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const MetaPill({
    super.key,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Source picker option card (Camera, Gallery, Record, Upload)
class SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const SourceOption({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small icon button with optional tooltip (share, copy, etc.)
class ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const ActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSoft),
              boxShadow: AppTheme.softShadow,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Show session-expired dialog and redirect to login
void showSessionExpiredDialog(BuildContext context, Widget loginPage) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Text(
        'Session Expired',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        'Your session has expired. Please sign in again to continue.',
        style: TextStyle(
          color: AppColors.textSecondary,
          height: 1.45,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => loginPage),
              (_) => false,
            );
          },
          child: const Text('Sign In'),
        ),
      ],
    ),
  );
}

/// ─────────────────────────────────────────────────────────
/// Custom Page Route Transitions
/// ─────────────────────────────────────────────────────────

class AppRoute {
  /// Slide + fade transition for premium navigation feel
  static Route<T> slide<T>(Widget page, {bool fullscreenDialog = false}) {
    return PageRouteBuilder<T>(
      fullscreenDialog: fullscreenDialog,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
              ),
            ),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }

  /// Scale + fade transition for modal-style pages
  static Route<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// Quota Progress Bar
/// ─────────────────────────────────────────────────────────

class QuotaProgressBar extends StatelessWidget {
  final String label;
  final IconData icon;
  final QuotaTypeStatus status;
  final String unit;

  const QuotaProgressBar({
    super.key,
    required this.label,
    required this.icon,
    required this.status,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    final percent = status.usedPercent;
    final color = status.isBlocked
        ? AppColors.error
        : percent > 0.9
            ? AppColors.error
            : percent > 0.7
                ? AppColors.warning
                : AppColors.success;

    final String usedStr;
    final String limitStr;
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

    if (unit.toLowerCase() == 'seconds') {
      final usedParts = status.used.toStringAsFixed(1).split('.');
      final usedWhole = usedParts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
      usedStr = '$usedWhole.${usedParts[1]}';

      final limitParts = status.limit.toStringAsFixed(1).split('.');
      final limitWhole = limitParts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
      limitStr = '$limitWhole.${limitParts[1]}';
    } else {
      final usedVal = status.used.toInt();
      usedStr = usedVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]},');

      final limitVal = status.limit.toInt();
      limitStr = limitVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]},');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$usedStr / $limitStr $unit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: status.isBlocked ? AppColors.error : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────
/// Quota Blocked Banner
/// ─────────────────────────────────────────────────────────

class QuotaBlockedBanner extends StatelessWidget {
  final String analysisType;

  const QuotaBlockedBanner({
    super.key,
    required this.analysisType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.block_rounded,
            size: 20,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Limit Reached',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You have reached your weekly limit for $analysisType analysis. Your quota resets next Monday.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
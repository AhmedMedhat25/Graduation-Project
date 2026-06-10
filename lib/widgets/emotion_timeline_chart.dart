import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/emotion_result.dart';
import '../theme.dart';

class EmotionTimelineChart extends StatelessWidget {
  final EmotionResult? result;

  const EmotionTimelineChart({
    super.key,
    this.result,
  });

  static final List<_EmotionSeries> _series = [
    _EmotionSeries(
      key: 'anger',
      label: 'Anger',
      color: const Color(0xFFE74C3C),
      icon: Icons.whatshot_rounded,
    ),
    _EmotionSeries(
      key: 'disgust',
      label: 'Disgust',
      color: const Color(0xFF2ECC71),
      icon: Icons.sentiment_very_dissatisfied_rounded,
    ),
    _EmotionSeries(
      key: 'fear',
      label: 'Fear',
      color: const Color(0xFF9B59B6),
      icon: Icons.visibility_off_rounded,
    ),
    _EmotionSeries(
      key: 'joy',
      label: 'Joy',
      color: const Color(0xFFF39C12),
      icon: Icons.emoji_emotions_rounded,
    ),
    _EmotionSeries(
      key: 'neutral',
      label: 'Neutral',
      color: const Color(0xFF95A5A6),
      icon: Icons.circle_outlined,
    ),
    _EmotionSeries(
      key: 'sadness',
      label: 'Sadness',
      color: const Color(0xFF1A3A5C),
      icon: Icons.water_drop_rounded,
    ),
    _EmotionSeries(
      key: 'surprise',
      label: 'Surprise',
      color: const Color(0xFF1ABC9C),
      icon: Icons.bolt_rounded,
    ),
  ];

  static String _normalizeKey(String raw) {
    final k = raw.toLowerCase().trim();
    switch (k) {
      case 'happy':
      case 'happiness':
        return 'joy';
      case 'angry':
      case 'mad':
        return 'anger';
      case 'sad':
        return 'sadness';
      case 'fearful':
      case 'scared':
        return 'fear';
      case 'disgusted':
        return 'disgust';
      case 'surprised':
        return 'surprise';
      default:
        return k;
    }
  }

  static Map<String, double> _extractProbabilities(Map<String, dynamic> item) {
    final probabilities = <String, double>{};

    final mapSource = item['probabilities'] ??
        item['all_emotions'] ??
        item['scores'] ??
        item['emotions'];

    if (mapSource is Map) {
      mapSource.forEach((key, value) {
        final k = _normalizeKey(key.toString());
        double v = 0.0;

        if (value is num) {
          v = value.toDouble();
        } else if (value is Map) {
          final raw = value['confidence'] ?? value['score'];
          if (raw is num) v = raw.toDouble();
        }

        if (v > 1.0) v = v / 100.0;
        probabilities[k] = v.clamp(0.0, 1.0);
      });
    }

    if (probabilities.isEmpty) {
      final combined = item['combined_final_emotion'];
      if (combined is Map && combined['probabilities'] is Map) {
        (combined['probabilities'] as Map).forEach((key, value) {
          final k = _normalizeKey(key.toString());
          double v = 0.0;
          if (value is num) v = value.toDouble();
          if (v > 1.0) v = v / 100.0;
          probabilities[k] = v.clamp(0.0, 1.0);
        });
      }
    }

    if (probabilities.isEmpty) {
      final listSource = item['combined_results'] ?? item['results'];
      if (listSource is List) {
        for (final entry in listSource) {
          if (entry is Map) {
            final label = entry['label'] ?? entry['emotion'];
            final conf = entry['confidence'] ?? entry['score'];
            if (label != null && conf != null) {
              final k = _normalizeKey(label.toString());
              double v = 0.0;
              if (conf is num) v = conf.toDouble();
              if (v > 1.0) v = v / 100.0;
              probabilities[k] = v.clamp(0.0, 1.0);
            }
          }
        }
      }
    }

    if (probabilities.isEmpty) {
      final dominant = item['dominant'];
      if (dominant is Map) {
        final label = dominant['label'] ?? dominant['emotion'];
        final raw = dominant['confidence'] ??
            dominant['score'] ??
            dominant['confidence_percent'];
        if (label != null) {
          final k = _normalizeKey(label.toString());
          double v = 0.0;
          if (raw is num) v = raw.toDouble();
          if (v > 1.0) v = v / 100.0;
          probabilities[k] = v.clamp(0.0, 1.0);
        }
      }
    }

    if (probabilities.isEmpty && item['emotion'] != null) {
      final k = _normalizeKey(item['emotion'].toString());
      double v = 0.0;
      final raw = item['confidence'] ??
          item['score'] ??
          item['confidence_percent'] ??
          1.0;
      if (raw is num) v = raw.toDouble();
      if (v > 1.0) v = v / 100.0;
      probabilities[k] = v.clamp(0.0, 1.0);
    }

    return probabilities;
  }

  static double _extractTime(Map<String, dynamic> item, int index) {
    final raw = item['start'] ??
        item['start_time'] ??
        item['time'] ??
        item['offset'] ??
        item['timestamp_offset'] ??
        item['segment_index'];

    double value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      value = double.tryParse(raw) ?? index.toDouble();
    } else {
      value = index.toDouble();
    }

    if (value > 1000) value /= 1000.0;
    return value;
  }

  static String? _extractText(Map<String, dynamic> item) {
    final text = item['text'] ??
        item['sentence'] ??
        item['quote'] ??
        item['segment_text'] ??
        item['transcript'] ??
        item['words'] ??
        item['content'] ??
        item['speech'];

    final s = text?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int _findNearestTimelineIndex(
      List<Map<String, dynamic>> timeline,
      double x,
      ) {
    int bestIndex = 0;
    double bestDiff = double.infinity;

    for (int i = 0; i < timeline.length; i++) {
      final t = _extractTime(timeline[i], i);
      final diff = (t - x).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    final rawTimeline = result?.timeline;
    final timeline = rawTimeline != null
        ? List<Map<String, dynamic>>.from(rawTimeline)
        : null;

    final hasData = timeline != null && timeline.isNotEmpty;
    final type = result?.type ?? 'unknown';

    final Map<String, List<FlSpot>> emotionSpots = {
      for (final item in _series) item.key: <FlSpot>[],
    };

    double maxX = 1.0;

    if (hasData) {
      timeline.sort(
            (a, b) => _extractTime(a, 0).compareTo(_extractTime(b, 0)),
      );

      maxX = 0.0;
      double lastX = -1.0;

      for (int i = 0; i < timeline.length; i++) {
        final probabilities = _extractProbabilities(timeline[i]);
        double x = _extractTime(timeline[i], i);

        if (x <= lastX) {
          x = lastX + 1.0;
        }

        lastX = x;
        if (x > maxX) maxX = x;

        for (final series in _series) {
          final value = probabilities[series.key] ?? 0.0;
          emotionSpots[series.key]!.add(FlSpot(x, value));
        }
      }

      if (maxX == 0) maxX = 1.0;

      if (timeline.length == 1) {
        for (final series in _series) {
          final singleSpot = emotionSpots[series.key]!.first;
          emotionSpots[series.key]!.add(FlSpot(maxX + 1.0, singleSpot.y));
        }
        maxX += 1.0;
      }
    }

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChartHeader(
            type: type,
            segmentCount: hasData ? timeline.length : 0,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                _LegendRow(series: _series),
                const SizedBox(height: 22),
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: hasData
                      ? LineChart(
                    _buildChartData(
                      emotionSpots: emotionSpots,
                      maxX: maxX,
                      type: type,
                      timeline: timeline,
                    ),
                  )
                      : _EmptyTimelineState(type: type),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0);
  }

  LineChartData _buildChartData({
    required Map<String, List<FlSpot>> emotionSpots,
    required double maxX,
    required String type,
    required List<Map<String, dynamic>>? timeline,
  }) {
    final bottomInterval = maxX <= 3
        ? 1.0
        : maxX <= 8
        ? 2.0
        : maxX <= 14
        ? 3.0
        : (maxX / 5).ceilToDouble();

    return LineChartData(
      minX: 0,
      maxX: maxX,
      minY: 0,
      maxY: 1,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 0.2,
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppColors.borderSoft.withValues(alpha: 0.25),
          strokeWidth: 0.8,
          dashArray: [6, 4],
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSoft.withValues(alpha: 0.4),
            width: 1,
          ),
          left: BorderSide(
            color: AppColors.borderSoft.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipBorderRadius: BorderRadius.circular(14),
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          tooltipMargin: 16,
          getTooltipColor: (_) => const Color(0xFF1A2332),
          getTooltipItems: (touchedSpots) {
            final items = <LineTooltipItem?>[];
            bool addedQuote = false;

            for (int i = 0; i < touchedSpots.length; i++) {
              final spot = touchedSpots[i];

              if (spot.y < 0.01) {
                items.add(null);
                continue;
              }

              final series = _series[spot.barIndex];
              String text =
                  '${series.label}  ${(spot.y * 100).toStringAsFixed(1)}%';

              if (!addedQuote && timeline != null && timeline.isNotEmpty) {
                final timelineIndex = _findNearestTimelineIndex(timeline, spot.x);
                final quote = _extractText(timeline[timelineIndex]);
                if (quote != null && quote.isNotEmpty) {
                  text = '"$quote"\n$text';
                  addedQuote = true;
                }
              }

              items.add(
                LineTooltipItem(
                  text,
                  TextStyle(
                    color: series.color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              );
            }

            return items;
          },
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 38,
            interval: 0.2,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  value == 1 ? '1.0' : value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: bottomInterval,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                space: 8,
                child: Text(
                  type == 'text'
                      ? 'S${value.toInt() + 1}'
                      : '${value.toInt()}s',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      lineBarsData: _series.map((series) {
        return _buildLine(
          spots: emotionSpots[series.key] ?? const [],
          color: series.color,
        );
      }).toList(),
    );
  }

  LineChartBarData _buildLine({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      curveSmoothness: 0.35,
      color: color,
      barWidth: 2.8,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.isNotEmpty && spots.length <= 15,
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 3.5,
          color: color,
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _EmotionSeries {
  final String key;
  final String label;
  final Color color;
  final IconData icon;

  const _EmotionSeries({
    required this.key,
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _ChartHeader extends StatelessWidget {
  final String type;
  final int segmentCount;

  const _ChartHeader({
    required this.type,
    required this.segmentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.secondary.withValues(alpha: 0.03),
            AppColors.surface,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSoft.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.secondary.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.timeline_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emotion Timeline',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  type == 'text'
                      ? 'Emotional shift across text segments'
                      : type == 'video'
                      ? 'Emotional shift across video frames'
                      : type == 'photo' || type == 'image'
                      ? 'Emotional details in image'
                      : 'Emotional shift across audio segments',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (segmentCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type == 'text'
                        ? Icons.segment_rounded
                        : type == 'video'
                        ? Icons.movie_filter_rounded
                        : type == 'photo' || type == 'image'
                        ? Icons.image_search_rounded
                        : Icons.graphic_eq_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$segmentCount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
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

class _LegendRow extends StatelessWidget {
  final List<_EmotionSeries> series;

  const _LegendRow({required this.series});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: series
          .map(
            (s) => _LegendChip(
          label: s.label,
          color: s.color,
        ),
      )
          .toList(),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTimelineState extends StatelessWidget {
  final String type;

  const _EmptyTimelineState({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.secondary.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.borderSoft,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.show_chart_rounded,
                color: AppColors.textMuted,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No timeline data',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              type == 'text'
                  ? 'Data points appear with multi-sentence analysis.'
                  : type == 'video'
                  ? 'Data points appear with video frames analysis.'
                  : type == 'photo' || type == 'image'
                  ? 'Timeline is not available for static photos.'
                  : 'Data points appear with segmented audio analysis.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
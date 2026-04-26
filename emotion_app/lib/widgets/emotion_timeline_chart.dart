import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/emotion_result.dart';

class EmotionTimelineChart extends StatelessWidget {
  final EmotionResult? result;
  
  const EmotionTimelineChart({super.key, this.result});

  @override
  Widget build(BuildContext context) {
    // If no real data, use dummy data or return empty
    final bool hasData = result?.timeline != null && result!.timeline!.isNotEmpty;
    
    // We will build the spots dynamically
    final Map<String, List<FlSpot>> emotionSpots = {
      'anger': [], 'disgust': [], 'fear': [], 'joy': [], 
      'neutral': [], 'sadness': [], 'surprise': []
    };

    double maxX = 16.0;

    if (hasData) {
      final timeline = result!.timeline!;
      maxX = (timeline.length - 1).toDouble();
      if (maxX < 1) maxX = 1;

      for (int i = 0; i < timeline.length; i++) {
        final item = timeline[i];
        final probs = item['probabilities'] as Map<String, dynamic>? ?? {};
        
        final x = i.toDouble();
        
        emotionSpots.forEach((emotion, spots) {
          final val = (probs[emotion] as num?)?.toDouble() ?? 0.0;
          spots.add(FlSpot(x, val));
        });
      }
    } else {
      // DUMMY DATA FALLBACK REMOVED - all data must come from API
      emotionSpots.forEach((key, list) {
        list.add(const FlSpot(0, 0));
        list.add(const FlSpot(1, 0));
      });
      maxX = 1.0;
    }

    final isText = result?.type == 'text';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Emotion Timeline',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isText ? 'Emotional shift across sentences' : 'Temporal emotional shift across audio segments',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Top Right Dot Sequence
              Row(
                children: [
                  _dot(const Color(0xFFF59E0B)),
                  _dot(const Color(0xFFE53E3E)),
                  _dot(const Color(0xFF3B82F6)),
                  _dot(const Color(0xFF14B8A6)),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Legend
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildLegendItem('Anger', const Color(0xFFE53E3E)),
                _buildLegendItem('Disgust', const Color(0xFF06B6D4)),
                _buildLegendItem('Fear', const Color(0xFF3B82F6)),
                _buildLegendItem('Joy', const Color(0xFFF59E0B)),
                _buildLegendItem('Neutral', const Color(0xFF94A3B8)),
                _buildLegendItem('Sadness', const Color(0xFF1E3A8A)),
                _buildLegendItem('Surprise', const Color(0xFF14B8A6)),
              ],
            ),
          ),
          
          const SizedBox(height: 36),
          
          // Chart
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: 1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 0.2,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            value == 1.0 ? '1' : value.toStringAsFixed(1),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: ((maxX / 4).ceilToDouble() > 0) ? (maxX / 4).ceilToDouble() : 1.0,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          space: 8,
                          child: Text(
                            isText ? 'S${value.toInt()+1}' : '${(value * 2.5).toInt()}s',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildLine(emotionSpots['anger']!, const Color(0xFFE53E3E)),
                  _buildLine(emotionSpots['disgust']!, const Color(0xFF06B6D4)),
                  _buildLine(emotionSpots['fear']!, const Color(0xFF3B82F6)),
                  _buildLine(emotionSpots['joy']!, const Color(0xFFF59E0B)),
                  _buildLine(emotionSpots['neutral']!, const Color(0xFF94A3B8)),
                  _buildLine(emotionSpots['sadness']!, const Color(0xFF1E3A8A)),
                  _buildLine(emotionSpots['surprise']!, const Color(0xFF14B8A6)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      curveSmoothness: 0.35,
    );
  }

  Widget _dot(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2.5),
      width: 4.5,
      height: 4.5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 2, color: color),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

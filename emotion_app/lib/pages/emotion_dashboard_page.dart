import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/timeline_service.dart';
import '../models/emotion_result.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';

// ════════════════════════════════════════════════════════════
//  EMOTION DASHBOARD PAGE  –  Visual charts & insights
// ════════════════════════════════════════════════════════════
class EmotionDashboardPage extends StatefulWidget {
  const EmotionDashboardPage({super.key});

  @override
  State<EmotionDashboardPage> createState() => _EmotionDashboardPageState();
}


// Helper to safely capitalize first letter
String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _EmotionDashboardPageState extends State<EmotionDashboardPage>

    with SingleTickerProviderStateMixin {
  final _timelineService = TimelineService();
  List<EmotionResult> _allHistory = [];
  List<EmotionResult> _filteredHistory = [];
  bool _loading = true;
  String _filter = 'all';
  final _filters = ['all', 'text', 'audio', 'photo', 'video'];
  int _touchedPieIndex = -1;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
    TimelineService.refreshNotifier.addListener(_load);
  }

  @override
  void dispose() {
    TimelineService.refreshNotifier.removeListener(_load);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _timelineService.getHistory(); // We load the full history every time
    if (mounted) {
      setState(() {
        _allHistory = all;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    _filteredHistory = _filter == 'all'
        ? _allHistory
        : _allHistory.where((e) => e.type == _filter).toList();
  }

  // ── Derived data helpers ─────────────────────────────────
  Map<String, int> get _emotionCounts {
    final m = <String, int>{};
    for (final r in _allHistory) {
      m[r.emotion] = (m[r.emotion] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get _typeCounts {
    final m = <String, int>{};
    for (final r in _allHistory) {
      m[r.type] = (m[r.type] ?? 0) + 1;
    }
    return m;
  }

  /// Last 7 entries reversed for chronological bar chart
  List<EmotionResult> get _last7 =>
      _allHistory.take(7).toList().reversed.toList();

  String get _dominantEmotion {
    if (_emotionCounts.isEmpty) return '-';
    final top =
        _emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    return _cap(top.key);
  }

  double get _avgConfidence {
    if (_allHistory.isEmpty) return 0;
    return _allHistory.map((r) => r.confidence).reduce((a, b) => a + b) /
        _allHistory.length;
  }

  int get _positiveCount =>
      _allHistory.where((r) => ['happy', 'joy'].contains(r.emotion.toLowerCase())).length;
  int get _negativeCount => _allHistory
      .where((r) =>
          ['sad', 'sadness', 'angry', 'anger', 'fearful', 'fear', 'disgusted', 'disgust'].contains(r.emotion.toLowerCase()))
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Emotion Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: AppColors.textMid, size: 20),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          isScrollable: true,
          onTap: (_) => HapticFeedback.selectionClick(),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Trends'),
            Tab(text: 'By Type'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _allHistory.isEmpty
              ? AnimatedEmptyState(
                  icon: Icons.bar_chart_rounded,
                  title: 'No data yet',
                  subtitle: 'Complete some analyses to see\nyour emotion charts here.',
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildHistoryTab(),
                    _buildTrendsTab(),
                    _buildByTypeTab(),
                  ],
                ),
    );
  }

  // ═══════════════ HISTORY TAB ════════════════════════════
  Widget _buildHistoryTab() {
    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: _filters.length,
            itemBuilder: (_, i) {
              final f = _filters[i];
              final selected = _filter == f;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _filter = f;
                    _applyFilter();
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.cardBorder,
                    ),
                  ),
                  child: Text(
                    _cap(f),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textMid,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: _filteredHistory.isEmpty
              ? AnimatedEmptyState(
                  icon: Icons.filter_list_off_rounded,
                  title: 'No results',
                  subtitle: 'Try changing the filter above',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: _filteredHistory.length,
                    itemBuilder: (_, i) => TimelineEntryWidget(result: _filteredHistory[i]),
                  ),
                ),
        ),
      ],
    )
        .animate(delay: 200.ms)
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }

  // ═══════════════ OVERVIEW TAB ═══════════════════════════
  Widget _buildOverviewTab() {
    final counts = _emotionCounts;
    final total = counts.values.fold(0, (a, b) => a + b);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI cards
          Row(
            children: [
              _KpiCard(
                label: 'Total Scans',
                value: _allHistory.length.toString(),
                icon: Icons.analytics_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              _KpiCard(
                label: 'Avg Confidence',
                value: '${(_avgConfidence * 100).toInt()}%',
                icon: Icons.speed_rounded,
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _KpiCard(
                label: 'Positive',
                value: _positiveCount.toString(),
                icon: Icons.sentiment_satisfied_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              _KpiCard(
                label: 'Needs Care',
                value: _negativeCount.toString(),
                icon: Icons.sentiment_dissatisfied_rounded,
                color: AppColors.warning,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Dominant emotion banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  emotionColor(_dominantEmotion.toLowerCase()),
                  emotionColor(_dominantEmotion.toLowerCase())
                      .withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(
                  emotionEmoji(_dominantEmotion.toLowerCase()),
                  style: TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Most Frequent Emotion',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        _dominantEmotion,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${counts[_dominantEmotion.toLowerCase()] ?? 0}x',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pie chart
          SectionHeader(
              title: 'Emotion Distribution',
              subtitle: 'Tap a slice for details'),
          const SizedBox(height: 16),

          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 44,
                      pieTouchData: PieTouchData(
                        touchCallback: (evt, resp) {
                          if (!evt.isInterestedForInteractions || resp == null || resp.touchedSection == null) {
                            if (_touchedPieIndex != -1) {
                              setState(() => _touchedPieIndex = -1);
                            }
                            return;
                          }
                          final newIndex = resp.touchedSection!.touchedSectionIndex;
                          if (_touchedPieIndex != newIndex) {
                            setState(() => _touchedPieIndex = newIndex);
                          }
                        },
                      ),
                      sections: List.generate(sorted.length, (i) {
                        final e = sorted[i];
                        final pct = e.value / total;
                        final isTouched = i == _touchedPieIndex;
                        return PieChartSectionData(
                          value: e.value.toDouble(),
                          color: emotionColor(e.key),
                          radius: isTouched ? 68 : 55,
                          title: pct > 0.06
                              ? '${(pct * 100).toInt()}%'
                              : '',
                          titleStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sorted.take(5).map((e) {
                      final pct = e.value / total;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: emotionColor(e.key),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                _cap(e.key),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Text(
                              '${(pct * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Horizontal bar breakdown
          const SectionHeader(title: 'Full Breakdown'),
          const SizedBox(height: 12),
          ...sorted.map((e) {
            final pct = e.value / total;
            final color = emotionColor(e.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(emotionEmoji(e.key),
                              style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Text(
                            _cap(e.key),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark),
                          ),
                        ],
                      ),
                      Text(
                        '${e.value} · ${(pct * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, duration: 400.ms, curve: Curves.easeOut);
  }

  // ═══════════════ TRENDS TAB ═════════════════════════════
  Widget _buildTrendsTab() {
    final last7 = _last7;
    if (last7.isEmpty) {
      return AnimatedEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No trends yet',
        subtitle: 'Complete some analyses to see your trends',
      );
    }

    // Build bar groups for last 7 scans
    final barGroups = List.generate(last7.length, (i) {
      final r = last7[i];
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: r.confidence,
            gradient: LinearGradient(
              colors: [
                emotionColor(r.emotion),
                emotionColor(r.emotion).withValues(alpha: 0.6),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Confidence bar chart
          SectionHeader(
            title: 'Last 7 Analyses',
            subtitle: 'Confidence level per scan',
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  barGroups: barGroups,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 0.25,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: AppColors.cardBorder,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 0.25,
                        getTitlesWidget: (v, meta) => SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${(v * 100).toInt()}%',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textLight),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= last7.length) {
                            return SideTitleWidget(meta: meta, child: const SizedBox.shrink());
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 10,
                            child: Text(
                              emotionEmoji(last7[i].emotion),
                              style: const TextStyle(fontSize: 18),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: last7
                .map((r) => r.emotion)
                .toSet()
                .map((e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: emotionColor(e),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _cap(e),
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textMid),
                        ),
                      ],
                    ))
                .toList(),
          ),

          const SizedBox(height: 28),

          // Second Trend Chart: Emotion Mix
          SectionHeader(
            title: 'Recent Emotion Mix',
            subtitle: 'Frequency in last 7 analyses',
          ),
          const SizedBox(height: 16),
          
          Container(
            height: 140,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                      sections: _buildTrendPieSections(last7),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: _buildTrendPieLegend(last7),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Positive vs Negative ratio
          SectionHeader(
            title: 'Mood Balance',
            subtitle: 'Positive vs negative ratio',
          ),
          const SizedBox(height: 16),

          _buildMoodBalance(data: last7),

          const SizedBox(height: 28),

          // Recent entries list
          SectionHeader(
            title: 'Scan Details',
            subtitle: 'Last 7 individual scans',
          ),
          const SizedBox(height: 12),

          ...last7.reversed.take(7).map((r) {
            final color = emotionColor(r.emotion);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Text(emotionEmoji(r.emotion),
                      style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _cap(r.emotion),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontSize: 13),
                        ),
                        Text(r.type,
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLight)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(r.confidence * 100).toInt()}%',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 13),
                      ),
                      Text(_timeAgo(r.timestamp),
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textLight)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, duration: 400.ms, curve: Curves.easeOut);
  }

  Widget _buildMoodBalance({List<EmotionResult>? data}) {
    final history = data ?? _allHistory;
    final total = history.length;
    if (total == 0) return const SizedBox.shrink();

    final posEmotions = {'happy', 'joy'};
    final negEmotions = {'sad', 'sadness', 'angry', 'anger', 'fearful', 'fear', 'disgusted', 'disgust'};

    final posCount = history.where((r) => posEmotions.contains(r.emotion.toLowerCase())).length;
    final negCount = history.where((r) => negEmotions.contains(r.emotion.toLowerCase())).length;
    final neutCount = total - posCount - negCount;

    int posPct = ((posCount / total) * 100).round();
    int negPct = ((negCount / total) * 100).round();
    int neutPct = 100 - posPct - negPct;

    // Contextual insight
    String insight;
    IconData insightIcon;
    Color insightColor;
    if (posPct >= negPct && posPct >= neutPct) {
      insight = 'You\'re feeling mostly positive! Keep it up 🎉';
      insightIcon = Icons.trending_up_rounded;
      insightColor = AppColors.success;
    } else if (negPct > posPct && negPct > neutPct) {
      insight = 'Elevated negative emotions detected. Take care of yourself 💙';
      insightIcon = Icons.favorite_rounded;
      insightColor = AppColors.warning;
    } else {
      insight = 'Your mood has been mostly balanced lately';
      insightIcon = Icons.balance_rounded;
      insightColor = AppColors.neutral;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gradient stacked bar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    if (posPct > 0)
                      Expanded(
                        flex: posPct.clamp(1, 100),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF38B2AC), Color(0xFF48BB78)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: posPct >= 10
                              ? Text('$posPct%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5))
                              : null,
                        ),
                      ),
                    if (negPct > 0)
                      Expanded(
                        flex: negPct.clamp(1, 100),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFED8936), Color(0xFFE53E3E)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: negPct >= 10
                              ? Text('$negPct%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5))
                              : null,
                        ),
                      ),
                    if (neutPct > 0)
                      Expanded(
                        flex: neutPct.clamp(1, 100),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.neutral.withValues(alpha: 0.7),
                                AppColors.neutral,
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: neutPct >= 10
                              ? Text('$neutPct%',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5))
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Stat cards row
          Row(
            children: [
              _buildMoodStatCard('😊', 'Positive', posPct, posCount, AppColors.success),
              const SizedBox(width: 10),
              _buildMoodStatCard('😔', 'Needs Care', negPct, negCount, AppColors.warning),
              const SizedBox(width: 10),
              _buildMoodStatCard('😐', 'Neutral', neutPct, neutCount, AppColors.neutral),
            ],
          ),

          const SizedBox(height: 16),

          // Insight message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: insightColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(insightIcon, size: 18, color: insightColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 12,
                      color: insightColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodStatCard(String emoji, String label, int pct, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              '$pct%',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ BY TYPE TAB ════════════════════════════
  Widget _buildByTypeTab() {
    final typeCounts = _typeCounts;
    final total = _allHistory.length;
    final types = [
      {
        'key': 'text',
        'label': 'Text',
        'icon': Icons.text_fields_rounded,
        'color': const Color(0xFF4A90D9),
      },
      {
        'key': 'audio',
        'label': 'Audio',
        'icon': Icons.mic_rounded,
        'color': const Color(0xFF9F7AEA),
      },
      {
        'key': 'photo',
        'label': 'Photo',
        'icon': Icons.photo_camera_rounded,
        'color': const Color(0xFF48BB78),
      },
      {
        'key': 'video',
        'label': 'Video',
        'icon': Icons.videocam_rounded,
        'color': const Color(0xFFED8936),
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
            children: types.map((t) {
              final count = typeCounts[t['key']] ?? 0;
              final pct = total > 0 ? count / total : 0.0;
              final color = t['color'] as Color;
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(t['icon'] as IconData, color: color, size: 26),
                    const SizedBox(height: 12),
                    Text(
                      count.toString(),
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: color),
                    ),
                    Text(
                      t['label'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMid),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 4,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toInt()}% of total',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textLight),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Per-type emotion breakdown
          SectionHeader(
              title: 'Emotion per Type',
              subtitle: 'What emotions each source detects'),
          const SizedBox(height: 16),

          ...types.map((t) {
            final typeHistory =
                _allHistory.where((r) => r.type == t['key']).toList();
            if (typeHistory.isEmpty) return const SizedBox.shrink();

            final tCounts = <String, int>{};
            for (final r in typeHistory) {
              tCounts[r.emotion] = (tCounts[r.emotion] ?? 0) + 1;
            }
            final sorted = tCounts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final tTotal = typeHistory.length;
            final color = t['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(t['icon'] as IconData, color: color, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        t['label'] as String,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        '$tTotal scan${tTotal != 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...sorted.take(4).map((e) {
                    final pct = e.value / tTotal;
                    final eColor = emotionColor(e.key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(emotionEmoji(e.key),
                              style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: Text(
                              _cap(e.key),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMid),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor: eColor.withValues(alpha: 0.1),
                                valueColor:
                                    AlwaysStoppedAnimation(eColor),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${(pct * 100).toInt()}%',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, duration: 400.ms, curve: Curves.easeOut);
  }

  List<PieChartSectionData> _buildTrendPieSections(List<EmotionResult> data) {
    if (data.isEmpty) return [];
    final counts = <String, int>{};
    for (var r in data) {
      counts[r.emotion] = (counts[r.emotion] ?? 0) + 1;
    }
    final total = data.length;
    return counts.entries.map((e) {
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: emotionColor(e.key),
        radius: 35,
        title: '${((e.value / total) * 100).toInt()}%',
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  Widget _buildTrendPieLegend(List<EmotionResult> data) {
    final counts = <String, int>{};
    for (var r in data) {
      counts[r.emotion] = (counts[r.emotion] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.take(5).map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: emotionColor(e.key), shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_cap(e.key), style: TextStyle(fontSize: 11, color: AppColors.textMid)),
          ],
        ),
      )).toList(),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }
}

// ── KPI Card ──────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              color.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.textDark)),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

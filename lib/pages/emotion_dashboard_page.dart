import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/emotion_result.dart';
import '../services/timeline_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'analysis_workspace_page.dart';

// ════════════════════════════════════════════════════════════
//  EMOTION DASHBOARD PAGE – Refactored with consistent filters
// ════════════════════════════════════════════════════════════

class EmotionDashboardPage extends StatefulWidget {
  final int initialTabIndex;

  const EmotionDashboardPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<EmotionDashboardPage> createState() => EmotionDashboardPageState();
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

enum DashboardDateRange { all, last7Days, last30Days }

enum EmotionTone { positive, negative, neutral }

EmotionTone classifyEmotion(String emotion) {
  switch (emotion.toLowerCase()) {
    case 'happy':
    case 'joy':
      return EmotionTone.positive;
    case 'sad':
    case 'sadness':
    case 'angry':
    case 'anger':
    case 'fearful':
    case 'fear':
    case 'disgusted':
    case 'disgust':
      return EmotionTone.negative;
    default:
      return EmotionTone.neutral;
  }
}

class DashboardAnalytics {
  final List<EmotionResult> history;

  DashboardAnalytics(this.history);

  Map<String, int> get emotionCounts {
    final map = <String, int>{};
    for (final r in history) {
      map[r.emotion] = (map[r.emotion] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get typeCounts {
    final map = <String, int>{};
    for (final r in history) {
      map[r.type] = (map[r.type] ?? 0) + 1;
    }
    return map;
  }

  String get dominantEmotion {
    final counts = emotionCounts;
    if (counts.isEmpty) return 'neutral';
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get avgConfidence {
    if (history.isEmpty) return 0;
    final total = history.fold<double>(0, (sum, r) => sum + r.confidence);
    return total / history.length;
  }

  int get positiveCount =>
      history.where((r) => classifyEmotion(r.emotion) == EmotionTone.positive).length;

  int get negativeCount =>
      history.where((r) => classifyEmotion(r.emotion) == EmotionTone.negative).length;

  int get neutralCount =>
      history.where((r) => classifyEmotion(r.emotion) == EmotionTone.neutral).length;
}

class EmotionDashboardPageState extends State<EmotionDashboardPage>
    with SingleTickerProviderStateMixin {
  final TimelineService _timelineService = TimelineService();

  late final TabController _tabController;

  List<EmotionResult> _allHistory = [];
  bool _loading = true;

  String _historyTypeFilter = 'all';
  final List<String> _historyTypeFilters = ['all', 'text', 'audio', 'photo', 'video'];

  DashboardDateRange _dateRange = DashboardDateRange.all;
  int _touchedPieIndex = -1;

  void switchToTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
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
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final all = await _timelineService.getHistory();

      all.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (!mounted) return;

      setState(() {
        _allHistory = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnackbar(
        context,
        'Failed to load history. Please try again.',
        isError: true,
      );
    }
  }

  List<EmotionResult> get _dateRangeHistory {
    if (_dateRange == DashboardDateRange.all) return List<EmotionResult>.from(_allHistory);

    // Timestamps are stored in UTC — compare against UTC now, not Cairo time.
    final now = EmotionResult.utcNow();
    final cutoff = switch (_dateRange) {
      DashboardDateRange.last7Days => now.subtract(const Duration(days: 7)),
      DashboardDateRange.last30Days => now.subtract(const Duration(days: 30)),
      DashboardDateRange.all => DateTime.fromMillisecondsSinceEpoch(0),
    };

    return _allHistory.where((r) => r.timestamp.isAfter(cutoff)).toList();
  }

  List<EmotionResult> get _historyVisibleData {
    final base = _dateRangeHistory;
    if (_historyTypeFilter == 'all') return base;
    return base.where((e) => e.type == _historyTypeFilter).toList();
  }

  DashboardAnalytics get _analytics => DashboardAnalytics(_dateRangeHistory);

  Future<void> _confirmClearHistory() async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Clear All History?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will permanently delete all your analysis records. This action cannot be undone.',
          style: TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete All',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    final success = await _timelineService.clearCloudHistory();

    if (!mounted) return;

    if (success) {
      await _load();
      if (!mounted) return;
      showAppSnackbar(context, 'All history cleared successfully');
    } else {
      setState(() => _loading = false);
      showAppSnackbar(
        context,
        'Failed to clear history. Please try again.',
        isError: true,
      );
    }
  }

  Future<void> _handleDeleteRecord(EmotionResult result) async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Delete this record?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently remove the following analysis:',
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  Text(
                    emotionEmoji(result.emotion),
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatEmotionLabel(result.emotion),
                          style: TextStyle(
                            color: emotionColor(result.emotion),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${result.type.toUpperCase()} · ${(result.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _timelineService.deleteAnalysis(result);
    if (!mounted) return;

    if (success) {
      showAppSnackbar(context, 'Analysis deleted');
      await _load();
    } else {
      showAppSnackbar(
        context,
        'Failed to delete. Please try again.',
        isError: true,
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final hasData = _allHistory.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Emotion Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            onPressed: _load,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            color: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppColors.borderSoft),
            ),
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearHistory();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Clear All History',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          onTap: (_) => HapticFeedback.selectionClick(),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.borderSoft,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'History'),
            Tab(text: 'Trends'),
            Tab(text: 'By Type'),
          ],
        ),
      ),
      body: _loading
          ? Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      )
          : !hasData
          ? AnimatedEmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'No data yet',
        subtitle: 'Complete some analyses to see your emotion charts here.',
        actionLabel: 'Start Analysis',
        onAction: () {
          Navigator.push(
            context,
            AppRoute.slide(const AnalysisWorkspacePage()),
          );
        },
      )
          : Column(
        children: [
          _buildGlobalDateRangeBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHistoryTab(),
                _buildTrendsTab(),
                _buildByTypeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalDateRangeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(
        children: DashboardDateRange.values.map((range) {
          final selected = _dateRange == range;
          final label = switch (range) {
            DashboardDateRange.last7Days => '7 Days',
            DashboardDateRange.last30Days => '30 Days',
            DashboardDateRange.all => 'All Time',
          };

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _dateRange = range;
                  _touchedPieIndex = -1;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.primaryGradient : null,
                  color: selected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected ? Colors.transparent : AppColors.borderSoft,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════ OVERVIEW TAB ═══════════════════════════
  Widget _buildOverviewTab() {
    final counts = _analytics.emotionCounts;
    final total = _dateRangeHistory.length;

    if (total == 0) {
      return const AnimatedEmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'No data for this period',
        subtitle: 'Try selecting a different date range or run a new analysis.',
      );
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _KpiCard(
                label: 'Total Scans',
                value: total.toString(),
                icon: Icons.analytics_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'Avg Confidence',
                value: '${(_analytics.avgConfidence * 100).toInt()}%',
                icon: Icons.speed_rounded,
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _KpiCard(
                label: 'Positive',
                value: _analytics.positiveCount.toString(),
                icon: Icons.sentiment_satisfied_rounded,
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _KpiCard(
                label: 'Needs Care',
                value: _analytics.negativeCount.toString(),
                icon: Icons.sentiment_dissatisfied_rounded,
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  emotionColor(_analytics.dominantEmotion),
                  emotionColor(_analytics.dominantEmotion).withValues(alpha: 0.72),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: emotionColor(_analytics.dominantEmotion).withValues(alpha: 0.24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Semantics(
              label:
              'Most frequent emotion is ${formatEmotionLabel(_analytics.dominantEmotion)}, detected ${counts[_analytics.dominantEmotion] ?? 0} times',
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emotionEmoji(_analytics.dominantEmotion),
                      style: const TextStyle(fontSize: 30),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Most Frequent Emotion',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatEmotionLabel(_analytics.dominantEmotion),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '${counts[_analytics.dominantEmotion] ?? 0}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Emotion Distribution',
            subtitle: 'Tap a slice to highlight the segment.',
          ),
          const SizedBox(height: 14),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              height: 320,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useVertical = constraints.maxWidth < 420;

                  final chart = SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 32,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response == null ||
                                response.touchedSection == null) {
                              if (_touchedPieIndex != -1) {
                                setState(() => _touchedPieIndex = -1);
                              }
                              return;
                            }

                            final newIndex = response.touchedSection!.touchedSectionIndex;
                            if (_touchedPieIndex != newIndex) {
                              setState(() => _touchedPieIndex = newIndex);
                            }
                          },
                        ),
                        sections: List.generate(sorted.length, (index) {
                          final entry = sorted[index];
                          final pct = total > 0 ? entry.value / total : 0.0;
                          final isTouched = index == _touchedPieIndex;

                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            color: emotionColor(entry.key),
                            radius: isTouched ? 72 : 58,
                            title: pct > 0.06 ? '${(pct * 100).toInt()}%' : '',
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          );
                        }),
                      ),
                    ),
                  );

                  final legend = SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sorted.take(5).map((entry) {
                        final pct = total > 0 ? entry.value / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: emotionColor(entry.key),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formatEmotionLabel(entry.key),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${(pct * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  );

                  if (useVertical) {
                    return Column(
                      children: [
                        Expanded(child: chart),
                        const SizedBox(height: 12),
                        legend,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: chart),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: legend),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Full Breakdown',
            subtitle: 'Share of each emotion in your selected range.',
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: Column(
              children: sorted.map((entry) {
                final pct = total > 0 ? entry.value / total : 0.0;
                final color = emotionColor(entry.key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            emotionEmoji(entry.key),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formatEmotionLabel(entry.key),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${entry.value} · ${(pct * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: color.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.04, end: 0, duration: 380.ms, curve: Curves.easeOut);
  }

  // ═══════════════ HISTORY TAB ════════════════════════════
  Widget _buildHistoryTab() {
    final visible = _historyVisibleData.reversed.toList();

    return Column(
      children: [
        SizedBox(
          height: 64,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: _historyTypeFilters.length,
            itemBuilder: (_, index) {
              final filter = _historyTypeFilters[index];
              final selected = _historyTypeFilter == filter;

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _historyTypeFilter = filter;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: selected ? AppColors.primaryGradient : null,
                    color: selected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.18)
                          : AppColors.borderSoft,
                    ),
                    boxShadow: selected
                        ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                        : [],
                  ),
                  child: Text(
                    _cap(filter),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const AnimatedEmptyState(
            icon: Icons.filter_list_off_rounded,
            title: 'No results',
            subtitle: 'Try changing the filter or date range.',
          )
              : RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: visible.length,
              itemBuilder: (_, index) {
                final result = visible[index];
                return TimelineEntryWidget(
                  key: ValueKey(
                    '${result.timestamp.millisecondsSinceEpoch}_${result.type}_${result.emotion}_$index',
                  ),
                  result: result,
                  onDelete: () => _handleDeleteRecord(result),
                );
              },
            ),
          ),
        ),
      ],
    )
        .animate(delay: 120.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.06, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }

  // ═══════════════ TRENDS TAB ═════════════════════════════
  Widget _buildTrendsTab() {
    final data = _dateRangeHistory;

    if (data.isEmpty) {
      return const AnimatedEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'No trends yet',
        subtitle: 'Complete some analyses to see your recent trends.',
      );
    }

    final barGroups = List.generate(data.length, (index) {
      final result = data[index];
      final color = emotionColor(result.emotion);

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: result.confidence,
            width: 28,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8),
            ),
            gradient: LinearGradient(
              colors: [
                color,
                color.withValues(alpha: 0.62),
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Analysis Trends',
            subtitle: 'Confidence level for your recent scans.',
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = data.length * 40.0;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth < constraints.maxWidth
                            ? constraints.maxWidth
                            : chartWidth,
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
                                color: AppColors.borderSoft,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 38,
                                  interval: 0.25,
                                  getTitlesWidget: (value, meta) => SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      '${(value * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= data.length) {
                                      return SideTitleWidget(
                                        meta: meta,
                                        child: const SizedBox.shrink(),
                                      );
                                    }

                                    return SideTitleWidget(
                                      meta: meta,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          emotionEmoji(data[index].emotion),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          PremiumCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: data
                        .map((e) => e.emotion)
                        .toSet()
                        .map(
                          (emotion) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: emotionColor(emotion),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatEmotionLabel(emotion),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                        .toList(),
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 38,
                      sections: _buildTrendPieSections(data),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Emotion Frequency',
            subtitle: 'Frequency distribution for the selected period.',
          ),
          const SizedBox(height: 14),
          PremiumCard(
            child: SizedBox(
              width: double.infinity,
              child: _buildTrendPieLegend(data),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Mood Balance',
            subtitle: 'Positive, negative, and neutral ratio.',
          ),
          const SizedBox(height: 14),
          _buildMoodBalance(data: data),
          const SizedBox(height: 28),
          const SectionHeader(
            title: 'Recent Scans',
            subtitle: 'A quick look at your selected period scans.',
          ),
          const SizedBox(height: 12),
          ...data.reversed.take(50).map((result) {
            final color = emotionColor(result.emotion);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emotionEmoji(result.emotion),
                      style: const TextStyle(fontSize: 22),
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
                            fontWeight: FontWeight.w700,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cap(result.type),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(result.confidence * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(result.timestamp),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.04, end: 0, duration: 380.ms, curve: Curves.easeOut);
  }

  Widget _buildMoodBalance({required List<EmotionResult> data}) {
    final analytics = DashboardAnalytics(data);
    final total = data.length;
    if (total == 0) return const SizedBox.shrink();

    final posCount = analytics.positiveCount;
    final negCount = analytics.negativeCount;
    final neutCount = analytics.neutralCount;

    final posPct = ((posCount / total) * 100).round();
    final negPct = ((negCount / total) * 100).round();
    final neutPct = 100 - posPct - negPct;

    String insight;
    IconData insightIcon;
    Color insightColor;

    if (posPct >= negPct && posPct >= neutPct) {
      insight = 'You are trending mostly positive lately.';
      insightIcon = Icons.trending_up_rounded;
      insightColor = AppColors.success;
    } else if (negPct > posPct && negPct > neutPct) {
      insight = 'Higher negative emotion activity detected recently.';
      insightIcon = Icons.favorite_rounded;
      insightColor = AppColors.warning;
    } else {
      insight = 'Your recent emotional pattern looks fairly balanced.';
      insightIcon = Icons.balance_rounded;
      insightColor = AppColors.neutral;
    }

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 34,
                child: Row(
                  children: [
                    if (posPct > 0)
                      Expanded(
                        flex: posPct.clamp(1, 100),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.success,
                                AppColors.success.withValues(alpha: 0.78),
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: posPct >= 10
                              ? const SizedBox.shrink()
                              : null,
                        ),
                      ),
                    if (negPct > 0)
                      Expanded(
                        flex: negPct.clamp(1, 100),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.warning,
                                AppColors.error,
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: negPct >= 10
                              ? const SizedBox.shrink()
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
                                AppColors.neutral.withValues(alpha: 0.72),
                                AppColors.neutral,
                              ],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: neutPct >= 10
                              ? const SizedBox.shrink()
                              : null,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMoodStatCard(
                '😊',
                'Positive',
                posPct,
                posCount,
                AppColors.success,
              ),
              const SizedBox(width: 10),
              _buildMoodStatCard(
                '😔',
                'Needs Care',
                negPct,
                negCount,
                AppColors.warning,
              ),
              const SizedBox(width: 10),
              _buildMoodStatCard(
                '😐',
                'Neutral',
                neutPct,
                neutCount,
                AppColors.neutral,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: insightColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: insightColor.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  insightIcon,
                  size: 18,
                  color: insightColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 12.5,
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

  Widget _buildMoodStatCard(
      String emoji,
      String label,
      int pct,
      int count,
      Color color,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.14),
          ),
        ),
        child: Column(
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$pct%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$label ($count)',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════ BY TYPE TAB ════════════════════════════
  Widget _buildByTypeTab() {
    final data = _dateRangeHistory;
    final total = data.length;

    if (total == 0) {
      return const AnimatedEmptyState(
        icon: Icons.category_outlined,
        title: 'No data for this period',
        subtitle: 'Try selecting a different date range or run a new analysis.',
      );
    }

    final analytics = DashboardAnalytics(data);
    final typeCounts = analytics.typeCounts;

    final types = [
      {
        'key': 'text',
        'label': 'Text',
        'icon': Icons.text_fields_rounded,
        'color': AppColors.primary,
      },
      {
        'key': 'audio',
        'label': 'Audio',
        'icon': Icons.mic_rounded,
        'color': AppColors.fearful,
      },
      {
        'key': 'photo',
        'label': 'Photo',
        'icon': Icons.photo_camera_rounded,
        'color': AppColors.disgusted,
      },
      {
        'key': 'video',
        'label': 'Video',
        'icon': Icons.videocam_rounded,
        'color': AppColors.surprised,
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: types.map((type) {
              final key = type['key'] as String;
              final label = type['label'] as String;
              final icon = type['icon'] as IconData;
              final color = type['color'] as Color;

              final count = typeCounts[key] ?? 0;
              final pct = total > 0 ? count / total : 0.0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSoft),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.12),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(pct * 100).toInt()}% of total',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Emotion per Type',
            subtitle: 'The most common emotions detected in each source.',
          ),
          const SizedBox(height: 14),
          ...types.map((type) {
            final key = type['key'] as String;
            final label = type['label'] as String;
            final icon = type['icon'] as IconData;
            final color = type['color'] as Color;

            final typeHistory = data.where((r) => r.type == key).toList();
            if (typeHistory.isEmpty) return const SizedBox.shrink();

            final counts = <String, int>{};
            for (final r in typeHistory) {
              counts[r.emotion] = (counts[r.emotion] ?? 0) + 1;
            }

            final sorted = counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            final typeTotal = typeHistory.length;

            return PremiumCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: color,
                          fontSize: 14.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$typeTotal scan${typeTotal != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ...sorted.take(4).map((entry) {
                    final pct = entry.value / typeTotal;
                    final emotionClr = emotionColor(entry.key);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(
                            emotionEmoji(entry.key),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 78,
                            child: Text(
                              formatEmotionLabel(entry.key),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 7,
                                backgroundColor: emotionClr.withValues(alpha: 0.10),
                                valueColor: AlwaysStoppedAnimation(emotionClr),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '${(pct * 100).toInt()}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ).animate().fadeIn(duration: 320.ms);
          }),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms)
        .slideY(begin: 0.04, end: 0, duration: 380.ms, curve: Curves.easeOut);
  }

  List<PieChartSectionData> _buildTrendPieSections(List<EmotionResult> data) {
    if (data.isEmpty) return [];

    final counts = <String, int>{};
    for (final r in data) {
      counts[r.emotion] = (counts[r.emotion] ?? 0) + 1;
    }

    final total = data.length;

    return counts.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value.toDouble(),
        color: emotionColor(entry.key),
        radius: 38,
        title: '${((entry.value / total) * 100).toInt()}%',
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildTrendPieLegend(List<EmotionResult> data) {
    final counts = <String, int>{};
    for (final r in data) {
      counts[r.emotion] = (counts[r.emotion] ?? 0) + 1;
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sorted.take(5).map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: emotionColor(entry.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatEmotionLabel(entry.key),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _timeAgo(DateTime dt) {
    final now = DateTime.now().toUtc();
    final diff = now.difference(dt.toUtc());

    if (diff.isNegative || diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt.toLocal());
  }
}

// ── KPI Card ───────────────────────────────────────────────
class _KpiCard extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  @override
  Widget build(BuildContext context) {
    final numericStr = widget.value.replaceAll(RegExp(r'[^0-9.]'), '');
    final suffix = widget.value.replaceAll(RegExp(r'[0-9.]'), '');
    final numericVal = double.tryParse(numericStr) ?? 0;
    final isInteger = !widget.value.contains('.');

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.surface,
              widget.color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.color.withValues(alpha: 0.14),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 20,
              ),
            )
                .animate()
                .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
                .fadeIn(duration: 300.ms),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(widget.value),
                      tween: Tween(begin: 0, end: numericVal),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, animated, _) {
                        final displayVal = isInteger
                            ? animated.toInt().toString()
                            : animated.toStringAsFixed(0);
                        return Text(
                          '$displayVal$suffix',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: AppColors.textPrimary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
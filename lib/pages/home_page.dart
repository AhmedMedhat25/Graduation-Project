import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/emotion_result.dart';
import '../services/alerts_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/timeline_service.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import 'alerts_page.dart';
import 'analysis_workspace_page.dart';
import 'emotion_dashboard_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  final GlobalKey<EmotionDashboardPageState> _dashboardKey =
      GlobalKey<EmotionDashboardPageState>();

  void _goToInsights() {
    setState(() {
      _currentIndex = 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dashboardKey.currentState?.switchToTab(1); // 1 = History tab
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardTab(onSeeAllTapped: _goToInsights),
      EmotionDashboardPage(key: _dashboardKey),
      const ProfilePage(),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, _, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            final now = DateTime.now();
            if (_lastBackPress != null &&
                now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
              SystemNavigator.pop();
              return;
            }

            _lastBackPress = now;

            ScaffoldMessenger.of(context)
              ..removeCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Press back again to exit'),
                  duration: Duration(seconds: 2),
                ),
              );
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.borderSoft),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _NavItem(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        isActive: _currentIndex == 0,
                        onTap: () => setState(() => _currentIndex = 0),
                      ),
                      _NavItem(
                        icon: Icons.pie_chart_outline_rounded,
                        activeIcon: Icons.pie_chart_rounded,
                        label: 'Insights',
                        isActive: _currentIndex == 1,
                        onTap: () => setState(() => _currentIndex = 1),
                      ),
                      _NavItem(
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profile',
                        isActive: _currentIndex == 2,
                        onTap: () => setState(() => _currentIndex = 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
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
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isActive ? 18 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                size: 22,
                color: isActive ? AppColors.primary : AppColors.textMuted,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: isActive
                    ? Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardTab extends StatefulWidget {
  final VoidCallback onSeeAllTapped;

  const _DashboardTab({required this.onSeeAllTapped});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final _authService = AuthService();
  final _timelineService = TimelineService();
  final _alertsService = AlertsService();

  String _userName = '';
  List<EmotionResult> _recentHistory = [];
  Map<String, int> _weeklyCounts = {};
  int _totalScans = 0;
  int _unreadAlerts = 0;
  int _streak = 0;
  bool _isLoading = true;
  String _dailyQuote = '';

  final List<String> _quotes = const [
    'Every day is a new beginning.',
    'Your emotions are valid.',
    'Breathe, you’ve got this.',
    'Small steps every day.',
    'Mindfulness is key.',
    'Awareness creates clarity.',
  ];

  final List<_AnalysisType> _analysisTypes = const [
    _AnalysisType(
      title: 'Text',
      subtitle: 'Analyze written text',
      icon: Icons.text_fields_rounded,
      color: Color(0xFF4A90D9),
      page: AnalysisWorkspacePage(initialIndex: 0),
    ),
    _AnalysisType(
      title: 'Audio',
      subtitle: 'Analyze voice and sound',
      icon: Icons.mic_rounded,
      color: Color(0xFF9F7AEA),
      page: AnalysisWorkspacePage(initialIndex: 1),
    ),
    _AnalysisType(
      title: 'Photo',
      subtitle: 'Analyze facial cues',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFF48BB78),
      page: AnalysisWorkspacePage(initialIndex: 2),
    ),
    _AnalysisType(
      title: 'Video',
      subtitle: 'Analyze video content',
      icon: Icons.videocam_rounded,
      color: Color(0xFFED8936),
      page: AnalysisWorkspacePage(initialIndex: 3),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _dailyQuote = _quotes[Random().nextInt(_quotes.length)];
    _loadData();
    TimelineService.refreshNotifier.addListener(_loadData);
  }

  @override
  void dispose() {
    TimelineService.refreshNotifier.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final user = await _authService.getCurrentUser();
      final history = await _timelineService.getHistory();
      final unread = await _alertsService.getUnreadCount();
      final counts =
      await _timelineService.getEmotionCounts(cachedHistory: history);
      final userStreak =
      await _timelineService.getStreak(cachedHistory: history);

      if (!mounted) return;

      setState(() {
        _userName = (user?.name ?? 'there').split(' ').first;
        _recentHistory = history.take(3).toList();
        _totalScans = history.length;
        _unreadAlerts = unread;
        _streak = userStreak;
        _weeklyCounts = counts;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAppSnackbar(
        context,
        'Failed to load dashboard. Pull down to retry.',
        isError: true,
      );
    }
  }

  Future<void> _openAlerts() async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      AppRoute.scale(const AlertsPage()),
    );
    _loadData();
  }

  Future<void> _openAnalysisPage(Widget page) async {
    HapticFeedback.lightImpact();
    await Navigator.push(
      context,
      AppRoute.slide(page),
    );
    _loadData();
  }

  Future<bool> _confirmDeleteDialog(EmotionResult result) async {
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

    return confirmed ?? false;
  }

  Future<void> _deleteAnalysis(EmotionResult result) async {
    final success = await _timelineService.deleteAnalysis(result);

    if (!mounted) return;

    if (success) {
      showAppSnackbar(context, 'Analysis deleted');
      _loadData();
    } else {
      showAppSnackbar(context, 'Failed to delete analysis', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedEmotionEntries = _weeklyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEmotionKey =
    sortedEmotionEntries.isNotEmpty ? sortedEmotionEntries.first.key : '';

    final hasWeeklyData =
        sortedEmotionEntries.isNotEmpty && sortedEmotionEntries.first.value > 0;

    final chartEntries = sortedEmotionEntries.take(5).toList();

    final double chartMax = chartEntries.isEmpty
        ? 4.0
        : max<double>(
      chartEntries
          .map((e) => e.value.toDouble())
          .reduce((a, b) => a > b ? a : b),
      4.0,
    );

    final barGroups = List.generate(chartEntries.length, (index) {
      final entry = chartEntries[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            width: 14,
            color: emotionColor(entry.key),
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader().animate().fadeIn(duration: 400.ms).slideY(
                  begin: -0.04,
                  end: 0,
                  curve: Curves.easeOutCubic,
                ),
                const SizedBox(height: 24),
                _buildHeroOverview(topEmotionKey: topEmotionKey)
                    .animate()
                    .fadeIn(delay: 80.ms, duration: 450.ms)
                    .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Analysis Types',
                  subtitle: 'Choose how you want to analyze emotions.',
                ).animate().fadeIn(delay: 160.ms),
                const SizedBox(height: 14),
                _buildAnalysisGrid(),
                const SizedBox(height: 20),
                _buildWeeklySummary(
                  hasWeeklyData: hasWeeklyData,
                  topEmotionKey: topEmotionKey,
                  barGroups: barGroups,
                  chartMax: chartMax,
                )
                    .animate()
                    .fadeIn(delay: 260.ms, duration: 450.ms)
                    .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 16),
                _buildMoodInsight()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),
                _buildRecentActivity()
                    .animate()
                    .fadeIn(delay: 360.ms, duration: 450.ms)
                    .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Good night';
  }

  String _greetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return '☀️';
    if (hour >= 12 && hour < 17) return '🌤️';
    if (hour >= 17 && hour < 22) return '🌅';
    return '🌙';
  }

  String _moodInsightText() {
    if (_weeklyCounts.isEmpty) {
      return 'Start your first analysis to unlock weekly mood insights ✨';
    }
    final sorted = _weeklyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.first.key; // already normalized by EmotionResult
    final total = sorted.fold<int>(0, (s, e) => s + e.value);

    // Keys are always canonical (normalizeEmotionKey output):
    // joy, sadness, anger, fear, surprise, disgust, neutral
    if (top == 'joy') {
      return 'You\'ve been mostly joyful this week 🎉 — keep the positive energy going!';
    } else if (top == 'sadness') {
      return 'We noticed some sadness this week 💙 — remember to take care of yourself.';
    } else if (top == 'anger') {
      return 'A few intense moments this week 🔥 — try a breathing exercise to reset.';
    } else if (top == 'fear') {
      return 'Some anxious moments detected 🌊 — mindfulness can help you stay grounded.';
    } else if (top == 'disgust') {
      return 'Feeling unsettled this week 😤 — try to focus on what you can control.';
    } else if (top == 'surprise') {
      return 'Lots of unexpected moments this week 😲 — embrace the spontaneity!';
    } else if (total >= 5) {
      return 'Great consistency! $total analyses this week 📊 — you\'re building strong self-awareness.';
    }
    return 'Keep analyzing to build a clearer picture of your emotional patterns 🧠';
  }

  Widget _buildMoodInsight() {
    final insightText = _moodInsightText();
    final sorted = _weeklyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topKey = sorted.isNotEmpty ? sorted.first.key : '';
    final color = topKey.isNotEmpty ? emotionColor(topKey) : AppColors.primary;
    final emoji = topKey.isNotEmpty ? emotionEmoji(topKey) : '💡';

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.18),
                  color.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Mood Insight',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '✨ AI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  insightText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
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

  Widget _buildHeader() {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_timeGreeting()}, $_userName ${_greetingEmoji()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _dailyQuote,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            _ActionIconButton(
              icon: Icons.notifications_outlined,
              badgeCount: _unreadAlerts,
              onTap: _openAlerts,
            ),
            const SizedBox(width: 8),
            _ActionIconButton(
              icon: Icons.bar_chart_rounded,
              isGradient: true,
              onTap: widget.onSeeAllTapped,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroOverview({required String topEmotionKey}) {
    final textTheme = Theme.of(context).textTheme;
    final hasTopEmotion = topEmotionKey.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your dashboard',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your emotional insights across every modality.',
            style: textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OverviewChip(
                icon: Icons.analytics_rounded,
                label: 'Total scans',
                value: '$_totalScans',
              ),
              _OverviewChip(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                value: '$_streak day${_streak == 1 ? '' : 's'}',
                emoji: _streak >= 7
                    ? '🔥🔥'
                    : _streak >= 3
                        ? '🔥'
                        : null,
                isHighlighted: _streak >= 3,
              ),
              _OverviewChip(
                icon: hasTopEmotion
                    ? Icons.sentiment_satisfied_alt_rounded
                    : Icons.auto_graph_rounded,
                label: hasTopEmotion ? 'Top emotion' : 'Status',
                value: hasTopEmotion
                    ? formatEmotionLabel(topEmotionKey)
                    : (_isLoading ? 'Loading' : 'Getting started'),
                emoji: hasTopEmotion ? emotionEmoji(topEmotionKey) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _analysisTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final item = _analysisTypes[index];
        return _AnalysisCard(
          title: item.title,
          subtitle: item.subtitle,
          icon: item.icon,
          color: item.color,
          onTap: () => _openAnalysisPage(item.page),
        )
            .animate()
            .fadeIn(delay: (220 + (index * 80)).ms, duration: 350.ms)
            .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        );
      },
    );
  }



  Widget _buildWeeklySummary({
    required bool hasWeeklyData,
    required String topEmotionKey,
    required List<BarChartGroupData> barGroups,
    required double chartMax,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final sortedEntries = _weeklyCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalWeekly =
        sortedEntries.fold<int>(0, (sum, e) => sum + e.value);

    int posCount = 0;
    int negCount = 0;
    int neutralCount = 0;
    for (final e in _weeklyCounts.entries) {
      final k = e.key; // already normalized canonical key
      if (k == 'joy') {
        posCount += e.value;
      } else if (k == 'sadness' ||
          k == 'anger' ||
          k == 'fear' ||
          k == 'disgust') {
        negCount += e.value;
      } else {
        // surprise, neutral → neutral bucket
        neutralCount += e.value;
      }
    }
    final sentimentTotal = posCount + negCount + neutralCount;

    return PremiumCard(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Summary',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Your emotional snapshot',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.accent.withValues(alpha: 0.10),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      'This week',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Quick stat chips ────────────────────────────
          Row(
            children: [
              _PremiumStatCard(
                icon: Icons.document_scanner_rounded,
                label: 'Scans',
                value: '$totalWeekly',
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              _PremiumStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                value: '$_streak day${_streak == 1 ? '' : 's'}',
                color: AppColors.warning,
              ),
              const SizedBox(width: 12),
              _PremiumStatCard(
                icon: Icons.notifications_active_rounded,
                label: 'Alerts',
                value: '$_unreadAlerts',
                color: _unreadAlerts > 0 ? AppColors.error : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Dominant emotion hero ───────────────────────
          if (hasWeeklyData) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    emotionColor(topEmotionKey).withValues(alpha: 0.15),
                    emotionColor(topEmotionKey).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: emotionColor(topEmotionKey).withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: emotionColor(topEmotionKey).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: emotionColor(topEmotionKey).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emotionEmoji(topEmotionKey),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOMINANT MOOD',
                          style: textTheme.labelSmall?.copyWith(
                            color: emotionColor(topEmotionKey).withValues(alpha: 0.8),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatEmotionLabel(topEmotionKey),
                          style: textTheme.headlineMedium?.copyWith(
                            color: emotionColor(topEmotionKey),
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: emotionColor(topEmotionKey),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: emotionColor(topEmotionKey).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Text(
                      '${_weeklyCounts[topEmotionKey] ?? 0}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: [
                  const Text('🧘', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'No dominant emotion yet — start scanning!',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Emotion breakdown list ─────────
          if (hasWeeklyData && sortedEntries.length > 1) ...[
            Text(
              'Emotion Breakdown',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            ...sortedEntries.take(5).map((entry) {
              final pct =
                  totalWeekly > 0 ? entry.value / totalWeekly : 0.0;
              final color = emotionColor(entry.key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        emotionEmoji(entry.key),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 70,
                      child: Text(
                        formatEmotionLabel(entry.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 10,
                          backgroundColor: color.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        textAlign: TextAlign.right,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // ── Mood sentiment bar ─────────────────────────
          if (sentimentTotal > 0) ...[
            Text(
              'Mood Balance',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: AppColors.surfaceSoft,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  if (posCount > 0)
                    Expanded(
                      flex: posCount,
                      child: Container(
                        margin: EdgeInsets.only(right: (neutralCount > 0 || negCount > 0) ? 3 : 0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.success.withValues(alpha: 0.7), AppColors.success],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  if (neutralCount > 0)
                    Expanded(
                      flex: neutralCount,
                      child: Container(
                        margin: EdgeInsets.only(right: negCount > 0 ? 3 : 0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.neutral.withValues(alpha: 0.6), AppColors.neutral.withValues(alpha: 0.8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  if (negCount > 0)
                    Expanded(
                      flex: negCount,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.warning.withValues(alpha: 0.8), AppColors.warning],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                _SentimentLabel(
                  emoji: '😊',
                  label: 'Positive',
                  count: posCount,
                  color: AppColors.success,
                ),
                _SentimentLabel(
                  emoji: '😐',
                  label: 'Neutral',
                  count: neutralCount,
                  color: AppColors.neutral,
                ),
                _SentimentLabel(
                  emoji: '😟',
                  label: 'Needs care',
                  count: negCount,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 22),
          ],


        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    final textTheme = Theme.of(context).textTheme;

    if (_recentHistory.isEmpty && !_isLoading) {
      return AnimatedEmptyState(
        icon: Icons.analytics_outlined,
        title: 'No analyses yet',
        subtitle: 'Choose an analysis type above or tap below to start your first emotional insight.',
        actionLabel: 'Analyze Now',
        onAction: () => _openAnalysisPage(const AnalysisWorkspacePage()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                title: 'Recent Activity',
                subtitle: 'Your latest emotion analyses.',
              ),
            ),
            TextButton(
              onPressed: widget.onSeeAllTapped,
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_recentHistory.isEmpty && _isLoading)
          PremiumCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Loading your recent activity...',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._recentHistory.asMap().entries.map((entry) {
            final index = entry.key;
            final result = entry.value;
            return Dismissible(
              key: ValueKey('${result.clientId ?? result.analysisId}-${result.timestamp}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDeleteDialog(result),
              onDismissed: (_) => _deleteAnalysis(result),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              child: TimelineEntryWidget(
                result: result,
                onDelete: () async {
                  final confirmed = await _confirmDeleteDialog(result);
                  if (confirmed) {
                    await _deleteAnalysis(result);
                  }
                },
              ),
            )
                .animate()
                .fadeIn(delay: (420 + (index * 90)).ms, duration: 350.ms)
                .slideX(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
          }),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isGradient;
  final int badgeCount;

  const _ActionIconButton({
    required this.icon,
    required this.onTap,
    this.isGradient = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: isGradient ? AppColors.primaryGradient : null,
            color: isGradient ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isGradient ? Colors.transparent : AppColors.borderSoft,
            ),
            boxShadow: isGradient ? [] : AppTheme.softShadow,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isGradient ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );

    if (badgeCount <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: Text(
                badgeCount > 9 ? '9+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? emoji;
  final bool isHighlighted;

  const _OverviewChip({
    required this.icon,
    required this.label,
    required this.value,
    this.emoji,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? emojiWidget;
    if (emoji != null) {
      emojiWidget = Text(
        emoji!,
        style: const TextStyle(fontSize: 16),
      );

      if (isHighlighted) {
        emojiWidget = emojiWidget
            .animate(onPlay: (c) => c.repeat())
            .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.25, 1.25),
              duration: 600.ms,
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              begin: const Offset(1.25, 1.25),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.easeInOut,
            );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.orange.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted
              ? Colors.orange.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            emojiWidget!
          else
            Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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



class _PremiumStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PremiumStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentimentLabel extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final Color color;

  const _SentimentLabel({
    required this.emoji,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.1)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _AnalysisCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnalysisCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnalysisCard> createState() => _AnalysisCardState();
}

class _AnalysisCardState extends State<_AnalysisCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: _pressed ? 0.97 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.borderSoft),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.20),
                      widget.color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.color,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  widget.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Start analysis',
                    style: textTheme.bodySmall?.copyWith(
                      color: widget.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: widget.color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalysisType {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;

  const _AnalysisType({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });
}
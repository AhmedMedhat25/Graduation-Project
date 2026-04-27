import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/timeline_service.dart';
import '../services/alerts_service.dart';
import '../models/emotion_result.dart';
import '../widgets/shared_widgets.dart';
import '../services/theme_service.dart';
import 'analysis_workspace_page.dart';
import 'profile_page.dart';
import 'alerts_page.dart';
import 'emotion_dashboard_page.dart';

// ════════════════════════════════════════════════════════════
//  HOME PAGE  (Dashboard)
// ════════════════════════════════════════════════════════════
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  DateTime? _lastBackPress;

  void _goToTimeline() => setState(() => _currentIndex = 1);

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _DashboardTab(onSeeAllTapped: _goToTimeline),
      const EmotionDashboardPage(),
      const ProfilePage(),
    ];

    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            final now = DateTime.now();
            if (_lastBackPress != null &&
                now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
              // Exit the app
              SystemNavigator.pop();
              return;
            }
            _lastBackPress = now;
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to exit'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: Scaffold(
            body: IndexedStack(index: _currentIndex, children: pages),
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

// ── Premium Bottom Nav Item ──────────────────────────────────
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 18 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primary : AppColors.textLight,
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Dashboard Tab ────────────────────────────────────────────
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
  String _dailyQuote = '';

  final List<String> _quotes = [
    "Every day is a new beginning.",
    "Your emotions are valid.",
    "Breathe, you've got this.",
    "Small steps every day.",
    "Mindfulness is key.",
    "Radiate positivity."
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
    final user = await _authService.getCurrentUser();
    final history = await _timelineService.getHistory();
    final unread = await _alertsService.getUnreadCount();
    final counts = await _timelineService.getEmotionCounts(cachedHistory: history);
    final userStreak = await _timelineService.getStreak(cachedHistory: history);

    if (mounted) {
      setState(() {
        _userName = user?.name.split(' ').first ?? 'there';
        _recentHistory = history.take(3).toList();
        _totalScans = history.length;
        _unreadAlerts = unread;
        _streak = userStreak;
        _weeklyCounts = counts;
      });
    }
  }

  final List<Map<String, dynamic>> _analysisTypes = [
    {
      'title': 'Text',
      'subtitle': 'Analyse written text',
      'icon': Icons.text_fields_rounded,
      'color': const Color(0xFF4A90D9),
      'page': const AnalysisWorkspacePage(initialIndex: 0),
    },
    {
      'title': 'Audio',
      'subtitle': 'Analyse voice & sound',
      'icon': Icons.mic_rounded,
      'color': const Color(0xFF9F7AEA),
      'page': const AnalysisWorkspacePage(initialIndex: 1),
    },
    {
      'title': 'Photo',
      'subtitle': 'Analyse facial expressions',
      'icon': Icons.photo_camera_rounded,
      'color': const Color(0xFF48BB78),
      'page': const AnalysisWorkspacePage(initialIndex: 2),
    },
    {
      'title': 'Video',
      'subtitle': 'Analyse video content',
      'icon': Icons.videocam_rounded,
      'color': const Color(0xFFED8936),
      'page': const AnalysisWorkspacePage(initialIndex: 3),
    },
  ];

  @override
  Widget build(BuildContext context) {
    String topThemeEmotion = 'Neutral';
    int maxCount = 0;
    _weeklyCounts.forEach((key, value) {
      if (value > maxCount) {
        maxCount = value;
        topThemeEmotion = key;
      }
    });

    List<BarChartGroupData> barGroups = [];
    int index = 0;
    _weeklyCounts.forEach((key, value) {
      if (index < 5) {
        barGroups.add(BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              color: emotionColor(key),
              width: 14,
              borderRadius: BorderRadius.circular(4),
            )
          ],
        ));
        index++;
      }
    });
    if (barGroups.isEmpty) {
      barGroups.add(BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 1, color: AppColors.neutral)]));
    }


    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $_userName 👋',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ).animate().fadeIn().slideX(begin: -0.2),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.warning.withValues(alpha: 0.15), AppColors.warning.withValues(alpha: 0.05)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '$_streak Day Streak',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.2),
                          const SizedBox(height: 2),
                          Text(
                            _dailyQuote,
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ).animate().fadeIn(delay: 150.ms).slideX(begin: -0.2),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        // Alerts bell
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AlertsPage()),
                          ).then((_) => _loadData()),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.cardBorder),
                                ),
                                child: Icon(
                                    Icons.notifications_outlined,
                                    size: 20,
                                    color: AppColors.textMid),
                              ),
                              if (_unreadAlerts > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        _unreadAlerts > 9
                                            ? '9+'
                                            : '$_unreadAlerts',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Dashboard button
                        GestureDetector(
                          onTap: widget.onSeeAllTapped,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF2D3A8C),
                                  Color(0xFF6C63FF)
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.bar_chart_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ).animate().fadeIn().scale(),
                  ],
                ),

                const SizedBox(height: 28),

                // Analysis Type Grid
                SectionHeader(
                  title: 'Analysis Types',
                  subtitle: 'Select input modality',
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 14),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: _analysisTypes.length,
                  itemBuilder: (ctx, i) {
                    final item = _analysisTypes[i];
                    return _AnalysisCard(
                      title: item['title'],
                      subtitle: item['subtitle'],
                      icon: item['icon'],
                      color: item['color'],
                      onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => item['page']))
                          .then((_) => _loadData()),
                    ).animate().fadeIn(delay: (300 + (i * 100)).ms).scale();
                  },
                ),

                const SizedBox(height: 16),

                // Emotion Summary Card (Feature B)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Weekly Summary', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                                const SizedBox(width: 4),
                                Text('Stable', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 12)),
                              ],
                            ),
                          ),
                        ]
                      ),
                      const SizedBox(height: 14),
                      Divider(color: AppColors.cardBorder, height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$_totalScans', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: AppColors.textDark)),
                                Text('Total scans', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: emotionColor(topThemeEmotion).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(emotionEmoji(topThemeEmotion), style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 6),
                                      Text(topThemeEmotion.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: emotionColor(topThemeEmotion)))
                                    ]
                                  ),
                                ),
                              ]
                            )
                          ),
                          SizedBox(
                            width: 120,
                            height: 60,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: max(maxCount.toDouble(), 4),
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(show: false),
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: barGroups,
                              ),
                            ),
                          )
                        ]
                      )
                    ]
                  )
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                const SizedBox(height: 24),

                // Recent Activity
                if (_recentHistory.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SectionHeader(title: 'Recent Activity'),
                      TextButton(
                        onPressed: widget.onSeeAllTapped,
                        child: Text('See all',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 8),
                  ..._recentHistory.asMap().entries.map((e) {
                    final r = e.value;
                    return TimelineEntryWidget(
                      result: r,
                      onDelete: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final success = await _timelineService.deleteAnalysis(r);
                            if (mounted && success) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Analysis deleted')),
                              );
                            }
                          },
                    ).animate().fadeIn(delay: (700 + (e.key * 100)).ms).slideX();
                  }),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.analytics_outlined,
                              size: 40, color: AppColors.textLight),
                          const SizedBox(height: 10),
                          Text(
                            'No analyses yet',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select a type above to get started',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Analysis Card with scale animation ───────────────────────
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
                      widget.color.withValues(alpha: 0.2),
                      widget.color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Hero(tag: 'icon_${widget.title}', child: Icon(widget.icon, color: widget.color, size: 24)),
              ),
              const Spacer(),
              Text(
                widget.title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textDark),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitle,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

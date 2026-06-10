import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/theme_service.dart';
import '../theme.dart';
import 'audio_emotion_page.dart';
import 'home_page.dart';
import 'photo_emotion_page.dart';
import 'text_emotion_page.dart';
import 'video_emotion_page.dart';

class AnalysisWorkspacePage extends StatefulWidget {
  final int initialIndex;

  const AnalysisWorkspacePage({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<AnalysisWorkspacePage> createState() => _AnalysisWorkspacePageState();
}

class _AnalysisWorkspacePageState extends State<AnalysisWorkspacePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    _WorkspaceTabItem(
      label: 'Text',
      icon: Icons.text_fields_rounded,
    ),
    _WorkspaceTabItem(
      label: 'Audio',
      icon: Icons.mic_rounded,
    ),
    _WorkspaceTabItem(
      label: 'Photo',
      icon: Icons.photo_camera_rounded,
    ),
    _WorkspaceTabItem(
      label: 'Video',
      icon: Icons.videocam_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    final safeInitialIndex = widget.initialIndex.clamp(0, _tabs.length - 1);

    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: safeInitialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleBack() {
    HapticFeedback.lightImpact();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomePage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: _handleBack,
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analysis Workspace',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Analyze text, audio, photo, and video',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(84),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderSoft),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: false,
                    onTap: (_) => HapticFeedback.selectionClick(),
                    padding: const EdgeInsets.all(4),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    indicator: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    tabs: _tabs
                        .map(
                          (tab) => Tab(
                        height: 44,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.icon, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tab.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: const [
              TextEmotionPage(),
              AudioEmotionPage(),
              PhotoEmotionPage(),
              VideoEmotionPage(),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceTabItem {
  final String label;
  final IconData icon;

  const _WorkspaceTabItem({
    required this.label,
    required this.icon,
  });
}
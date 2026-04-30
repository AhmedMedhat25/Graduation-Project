import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/theme_service.dart';
import 'home_page.dart';
import 'text_emotion_page.dart';
import 'audio_emotion_page.dart';
import 'photo_emotion_page.dart';
import 'video_emotion_page.dart';

class AnalysisWorkspacePage extends StatefulWidget {
  final int initialIndex;
  const AnalysisWorkspacePage({super.key, this.initialIndex = 0});

  @override
  State<AnalysisWorkspacePage> createState() => _AnalysisWorkspacePageState();
}

class _AnalysisWorkspacePageState extends State<AnalysisWorkspacePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Analysis Workspace', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                } else {
                  // If somehow stack is empty, return to HomePage dashboard
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
                }
              },
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textLight,
              indicatorColor: AppColors.primary,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              isScrollable: true,
              onTap: (_) => HapticFeedback.selectionClick(),
              tabs: const [
                Tab(icon: Icon(Icons.text_fields_rounded, size: 20), text: 'Text'),
                Tab(icon: Icon(Icons.mic_rounded, size: 20), text: 'Audio'),
                Tab(icon: Icon(Icons.photo_camera_rounded, size: 20), text: 'Photo'),
                Tab(icon: Icon(Icons.videocam_rounded, size: 20), text: 'Video'),
              ],
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

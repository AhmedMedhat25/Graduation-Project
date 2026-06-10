import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../models/emotion_result.dart';
import '../models/quota_status.dart';
import '../services/api_client.dart';
import '../services/quota_service.dart';
import '../services/video_emotion_service.dart';
import '../theme.dart';
import '../widgets/emotion_timeline_chart.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';

// ════════════════════════════════════════════════════════════
//  VIDEO EMOTION PAGE
// ════════════════════════════════════════════════════════════
class VideoEmotionPage extends StatefulWidget {
  const VideoEmotionPage({super.key});

  @override
  State<VideoEmotionPage> createState() => _VideoEmotionPageState();
}

class _VideoEmotionPageState extends State<VideoEmotionPage> {
  final VideoEmotionService _videoService = VideoEmotionService();
  final QuotaService _quotaService = QuotaService();
  final ImagePicker _picker = ImagePicker();

  File? _videoFile;
  bool _loading = false;
  String _loadingText = 'Analysing video...';
  EmotionResult? _result;
  String? _error;
  QuotaTypeStatus? _quotaStatus;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  void _handleError(dynamic e) {
    if (e is SessionExpiredException) {
      _showReLoginDialog();
      return;
    }

    String msg = e.toString();

    msg = msg
        .replaceFirst('VideoAnalysisException: ', '')
        .replaceFirst('Exception: ', '');

    if (msg.contains('(caused by: ') && msg.endsWith(')')) {
      final start = msg.indexOf('(caused by: ') + '(caused by: '.length;
      msg = msg.substring(start, msg.length - 1);
    }

    if (msg.contains('Session expired')) {
      _showReLoginDialog();
      return;
    }

    setState(() => _error = msg);
  }

  void _showReLoginDialog() {
    showSessionExpiredDialog(context, const LoginPage());
  }

  Future<void> _pickVideo(ImageSource source) async {
    HapticFeedback.selectionClick();

    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );

    if (picked == null) return;

    final file = File(picked.path);
    final sizeInMb = file.lengthSync() / (1024 * 1024);

    if (sizeInMb > 50) {
      setState(() {
        _error = 'File size must be under 50MB. Please choose a smaller video.';
        _videoFile = null;
        _result = null;
      });
      return;
    }

    setState(() {
      _videoFile = file;
      _result = null;
      _error = null;
    });
  }

  Future<void> _loadQuota() async {
    try {
      final quota = await _quotaService.getQuota();
      if (!mounted) return;
      setState(() => _quotaStatus = quota?.forType('video'));
    } catch (_) {}
  }

  Future<void> _analyse() async {
    if (_videoFile == null) {
      setState(() => _error = 'Please select a video file first.');
      return;
    }

    // ── Quota gate ──
    try {
      final quota = await _quotaService.getQuota();
      if (mounted) setState(() => _quotaStatus = quota?.forType('video'));
      if (_quotaStatus?.isBlocked == true) {
        if (mounted) {
          setState(() => _error = 'Weekly video analysis limit reached. Resets next Monday.');
        }
        return;
      }
    } catch (_) {}

    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _loadingText = 'Extracting video frames...';
      _error = null;
      _result = null;
    });

    try {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) {
          setState(() => _loadingText = 'Running multimodal analysis...');
        }
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) {
          setState(() => _loadingText = 'Aggregating timeline results...');
        }
      });

      final result = await _videoService.analyzeVideo(_videoFile!);


      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (mounted) _handleError(e);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _shareResult() {
    if (_result == null) return;

    final text =
        'My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via VIDEO analysis 🧠';

    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, 'Copied to clipboard!');
  }

  void _clearVideo() {
    HapticFeedback.lightImpact();
    setState(() {
      _videoFile = null;
      _result = null;
      _error = null;
    });
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Text(
                'Select Video Source',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a video from camera or gallery.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SourceOption(
                      icon: Icons.videocam_rounded,
                      label: 'Camera',
                      subtitle: 'Capture a new clip',
                      color: AppColors.surprised,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SourceOption(
                      icon: Icons.video_library_rounded,
                      label: 'Gallery',
                      subtitle: 'Choose from device',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        _pickVideo(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFileSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _fileName(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _videoFile != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader()
              .animate()
              .fadeIn(duration: 350.ms)
              .slideX(begin: -0.04, end: 0),
          const SizedBox(height: 18),
          _buildVideoCard()
              .animate()
              .fadeIn(delay: 80.ms, duration: 350.ms)
              .slideY(begin: 0.06, end: 0),
          const SizedBox(height: 14),
          PremiumCard(
            padding: const EdgeInsets.all(16),
            color: AppColors.surfaceSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.video_library_outlined,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Video analysis combines visual expression patterns and temporal cues to estimate emotional state across moments.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
          if (_quotaStatus != null) ...[
            const SizedBox(height: 12),
            QuotaProgressBar(
              label: 'Video',
              icon: Icons.videocam_rounded,
              status: _quotaStatus!,
              unit: 'seconds',
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
          ],
          if (_quotaStatus?.isBlocked == true) ...[
            const SizedBox(height: 12),
            const QuotaBlockedBanner(analysisType: 'Video'),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _loading
                ? AnalysisLoadingPanel(
              key: const ValueKey('video-loading'),
              text: _loadingText,
            )
                : PrimaryButton(
              key: const ValueKey('video-button'),
              label: 'Analyse Video',
              onTap: (_quotaStatus?.isBlocked == true) ? null : (hasVideo ? _analyse : null),
              loading: _loading,
              icon: Icons.camera_roll_rounded,
            ),
          ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
          if (_result != null) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Result',
                    subtitle: 'Detected emotion and confidence breakdown.',
                  ),
                ),
                const SizedBox(width: 12),
                ActionIconButton(
                  icon: Icons.share_rounded,
                  tooltip: 'Copy result',
                  onTap: _shareResult,
                ),
              ],
            ),
            const SizedBox(height: 14),
            EmotionResultCard(result: _result!),
            const SizedBox(height: 22),
            EmotionTimelineChart(result: _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Hero(
          tag: 'icon_Video',
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surprised.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.surprised.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.videocam_rounded,
              color: AppColors.surprised,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capture or upload a video to analyze emotion across visual moments and timeline shifts.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard() {
    final hasVideo = _videoFile != null;
    final accentColor = hasVideo ? AppColors.surprised : AppColors.primary;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Video Source',
                  subtitle: 'Use your camera or select a video from gallery.',
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(
                icon: Icons.cloud_done_rounded,
                label: 'Live API',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _loading ? null : _showSourcePicker,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: hasVideo
                        ? accentColor.withValues(alpha: 0.45)
                        : AppColors.borderSoft,
                    width: hasVideo ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasVideo
                            ? Icons.movie_creation_rounded
                            : Icons.slow_motion_video_rounded,
                        size: 36,
                        color: accentColor,
                      ),
                    )
                        .animate(
                      target: _loading ? 1 : 0,
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                        .scaleXY(
                      begin: 1,
                      end: 1.05,
                      duration: 900.ms,
                      curve: Curves.easeInOut,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasVideo
                          ? _fileName(_videoFile!)
                          : 'Tap to select a video',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: hasVideo
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Camera or gallery • MP4, MOV • Max 50MB • Up to 5 minutes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (hasVideo && !_loading) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          MetaPill(
                            label: _formatFileSize(_videoFile!),
                            icon: Icons.sd_storage_rounded,
                          ),
                          const MetaPill(
                            label: 'Ready to analyze',
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showSourcePicker,
                            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                            label: const Text('Change video'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _clearVideo,
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
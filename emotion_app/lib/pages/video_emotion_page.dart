import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/video_emotion_service.dart';
import '../services/timeline_service.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../models/emotion_result.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/emotion_timeline_chart.dart';
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
  final _videoService = VideoEmotionService();
  final _timelineService = TimelineService();
  final _alertsService = AlertsService();
  final _picker = ImagePicker();

  File? _videoFile;
  bool _loading = false;
  String _loadingText = 'Analysing Video...';
  EmotionResult? _result;
  String? _error;

  // ── Error handler ───────────────────────────────────────
  void _handleError(dynamic e) {
    if (e is SessionExpiredException) {
      _showReLoginDialog();
      return;
    }
    final msg = e.toString().replaceFirst('Exception: ', '');
    if (msg.contains('Session expired')) {
      _showReLoginDialog();
      return;
    }
    setState(() => _error = msg);
  }

  void _showReLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text(
          'Your session has expired. Please sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (picked != null) {
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
  }

  Future<void> _analyse() async {
    if (_videoFile == null) {
      setState(() => _error = 'Please select a video file first.');
      return;
    }
    setState(() {
      _loading = true;
      _loadingText = 'Extracting video frames...';
      _error = null;
      _result = null;
    });
    try {
      // Simulate stepped loading text
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) setState(() => _loadingText = 'Running multimodal analysis...');
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) setState(() => _loadingText = 'Aggregating timeline results...');
      });

      final result = await _videoService.analyzeVideo(_videoFile!);
      await _alertsService.generateAlert(result);

      final history = await _timelineService.getHistory();
      await _alertsService.checkStreak(history);

      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) _handleError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shareResult() {
    if (_result == null) return;
    final text = "My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via VIDEO analysis 🧠";
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, "Copied to clipboard!");
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Text('Select Video Source',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.videocam_rounded,
                    label: 'Camera',
                    color: const Color(0xFFED8936),
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.video_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFFF6AD55),
                    onTap: () {
                      Navigator.pop(context);
                      _pickVideo(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Hero(
                  tag: 'icon_Video',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFED8936).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFFED8936), size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Video Analysis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ).animate().fadeIn().slideX(begin: -0.2),

            const SizedBox(height: 24),

            // Upload area
            GestureDetector(
              onTap: _loading ? null : _showSourcePicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _videoFile != null
                        ? const Color(0xFFED8936)
                        : AppColors.cardBorder,
                    width: _videoFile != null ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFED8936).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.slow_motion_video_rounded,
                          size: 36, color: Color(0xFFED8936)),
                    ).animate(target: _loading ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.15,1.15), duration: 600.ms).shimmer(duration: 800.ms),
                    const SizedBox(height: 16),
                    Text(
                      _videoFile != null
                          ? _videoFile!.path.split(Platform.pathSeparator).last
                          : 'Tap to select a video',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: _videoFile != null
                            ? AppColors.textDark
                            : AppColors.textMid,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Camera or gallery • MP4, MOV (Max: 50MB)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                    if (_videoFile != null && !_loading) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _showSourcePicker,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Change video'),
                      ),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

            const SizedBox(height: 16),

            // Info card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.video_library_outlined,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Video analysis combines facial expression tracking and audio tone analysis for comprehensive results.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMid),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

            const SizedBox(height: 10),

            // Simulated API notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.science_rounded, size: 15, color: Colors.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Simulated — Video analysis runs locally. Cloud API coming soon.',
                      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 250.ms),

            if (_error != null) ...[
               const SizedBox(height: 20),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: AppColors.error.withValues(alpha: 0.08),
                   border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Row(
                   children: [
                     Icon(Icons.error_outline, color: AppColors.error),
                     const SizedBox(width: 12),
                     Expanded(child: Text(_error!, style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600))),
                   ],
                 ),
               ),
               const SizedBox(height: 12),
               ElevatedButton.icon(
                 onPressed: _videoFile == null ? _showSourcePicker : _analyse,
                 icon: const Icon(Icons.refresh_rounded),
                 label: Text(_videoFile == null ? 'Select Another Video' : 'Try Again'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.surface,
                   foregroundColor: AppColors.primary,
                   side: BorderSide(color: AppColors.primary),
                 ),
               ).animate().fadeIn(),
            ] else ...[
               const SizedBox(height: 20),
               PrimaryButton(
                 label: _loading ? _loadingText : 'Analyse Video',
                 onTap: _videoFile != null ? _analyse : null,
                 loading: _loading,
                 icon: Icons.camera_roll_rounded,
               ).animate(key: ValueKey(_loadingText)).fadeIn(delay: 300.ms).slideY(),
            ],

            if (_result != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SectionHeader(title: 'Result'),
                  IconButton(
                    icon: Icon(Icons.share_rounded, color: AppColors.primary),
                    onPressed: _shareResult,
                    tooltip: 'Share Result',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              EmotionResultCard(result: _result!),
              const SizedBox(height: 24),
              EmotionTimelineChart(result: _result!),
            ],
          ],
      ),
    );
  }
}

class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

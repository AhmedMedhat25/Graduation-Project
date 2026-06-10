import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';

import '../models/emotion_result.dart';
import '../models/quota_status.dart';
import '../services/api_client.dart';
import '../services/photo_emotion_service.dart';
import '../services/quota_service.dart';
import '../theme.dart';
import '../widgets/emotion_timeline_chart.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';

// ════════════════════════════════════════════════════════════
//  PHOTO EMOTION PAGE
// ════════════════════════════════════════════════════════════
class PhotoEmotionPage extends StatefulWidget {
  const PhotoEmotionPage({super.key});

  @override
  State<PhotoEmotionPage> createState() => _PhotoEmotionPageState();
}

class _PhotoEmotionPageState extends State<PhotoEmotionPage> {
  final PhotoEmotionService _photoService = PhotoEmotionService();
  final QuotaService _quotaService = QuotaService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _loading = false;
  String _loadingText = 'Analysing photo...';
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
        .replaceFirst('PhotoAnalysisException: ', '')
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

  Future<void> _loadQuota() async {
    try {
      final quota = await _quotaService.getQuota();
      if (!mounted) return;
      setState(() => _quotaStatus = quota?.forType('photo'));
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    HapticFeedback.selectionClick();

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 85,
    );

    if (picked == null) return;

    final file = File(picked.path);
    final sizeInMb = file.lengthSync() / (1024 * 1024);

    if (sizeInMb > 15) {
      setState(() {
        _error = 'File size must be under 15MB. Please choose a smaller photo.';
        _imageFile = null;
        _result = null;
      });
      return;
    }

    setState(() {
      _imageFile = file;
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyse() async {
    if (_imageFile == null) {
      setState(() => _error = 'Please select an image first.');
      return;
    }

    // ── Quota gate ──
    try {
      final quota = await _quotaService.getQuota();
      if (mounted) setState(() => _quotaStatus = quota?.forType('photo'));
      if (_quotaStatus?.isBlocked == true) {
        if (mounted) {
          setState(() => _error = 'Weekly photo analysis limit reached. Resets next Monday.');
        }
        return;
      }
    } catch (_) {}

    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _loadingText = 'Scanning image...';
      _error = null;
      _result = null;
    });

    try {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) {
          setState(() => _loadingText = 'Detecting facial features...');
        }
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) {
          setState(() => _loadingText = 'Classifying expressions...');
        }
      });

      final result = await _photoService.analyzePhoto(_imageFile!);


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
        'My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via PHOTO analysis 🧠';

    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, 'Copied to clipboard!');
  }

  void _clearImage() {
    HapticFeedback.lightImpact();
    setState(() {
      _imageFile = null;
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
                'Select Image Source',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a photo from camera or gallery.',
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
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      subtitle: 'Capture a new photo',
                      color: AppColors.disgusted,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SourceOption(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      subtitle: 'Choose from device',
                      color: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
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

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null;

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
          _buildImageCard()
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
                    Icons.face_rounded,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Photo analysis detects visible facial expressions and visual cues to estimate emotion.',
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
              label: 'Photo',
              icon: Icons.photo_camera_rounded,
              status: _quotaStatus!,
              unit: 'images',
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
          ],
          if (_quotaStatus?.isBlocked == true) ...[
            const SizedBox(height: 12),
            const QuotaBlockedBanner(analysisType: 'Photo'),
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
              key: const ValueKey('photo-loading'),
              text: _loadingText,
            )
                : PrimaryButton(
              key: const ValueKey('photo-button'),
              label: 'Analyse Photo',
              onTap: (_quotaStatus?.isBlocked == true) ? null : (hasImage ? _analyse : null),
              loading: _loading,
              icon: Icons.search_rounded,
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
          tag: 'icon_Photo',
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.disgusted.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.disgusted.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.photo_camera_rounded,
              color: AppColors.disgusted,
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
                'Photo Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capture or upload a photo to analyze emotional expression from visual cues.',
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

  Widget _buildImageCard() {
    final hasImage = _imageFile != null;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Image Source',
                  subtitle: 'Use your camera or choose a photo from gallery.',
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
                height: 250,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: hasImage
                        ? AppColors.disgusted.withValues(alpha: 0.45)
                        : AppColors.borderSoft,
                    width: hasImage ? 1.4 : 1,
                  ),
                ),
                child: hasImage
                    ? Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      ).animate().fadeIn(duration: 250.ms),
                    ),
                    if (_loading)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Center(
                          child: Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo_camera_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .scaleXY(
                            begin: 1,
                            end: 1.08,
                            duration: 800.ms,
                            curve: Curves.easeInOut,
                          ),
                        ),
                      ),
                    if (!_loading)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Row(
                          children: [
                            _OverlayCircleButton(
                              icon: Icons.edit_rounded,
                              onTap: _showSourcePicker,
                            ),
                            const SizedBox(width: 8),
                            _OverlayCircleButton(
                              icon: Icons.delete_outline_rounded,
                              onTap: _clearImage,
                            ),
                          ],
                        ),
                      ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.54),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image_outlined,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatFileSize(_imageFile!),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Text(
                              'Ready',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        color: AppColors.disgusted.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: 36,
                        color: AppColors.disgusted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to select a photo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Camera or gallery • JPG, PNG • Max 15MB',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasImage && !_loading) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                MetaPill(
                  label: _formatFileSize(_imageFile!),
                  icon: Icons.sd_storage_rounded,
                ),
                const MetaPill(
                  label: 'Ready to analyze',
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// _OverlayCircleButton kept as photo-specific
class _OverlayCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _OverlayCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.56),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}
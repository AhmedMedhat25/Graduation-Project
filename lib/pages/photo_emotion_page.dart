import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../services/photo_emotion_service.dart';
import '../services/timeline_service.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../models/emotion_result.dart';
import '../theme.dart';
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
  final _photoService = PhotoEmotionService();
  final _timelineService = TimelineService();
  final _alertsService = AlertsService();
  final _picker = ImagePicker();

  File? _imageFile;
  bool _loading = false;
  String _loadingText = 'Analysing Photo...';
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

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
        source: source, maxWidth: 1280, imageQuality: 85);
    if (picked != null) {
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
  }

  Future<void> _analyse() async {
    if (_imageFile == null) {
      setState(() => _error = 'Please select an image first.');
      return;
    }
    setState(() {
      _loading = true;
      _loadingText = 'Scanning image...';
      _error = null;
      _result = null;
    });
    try {
      // Simulate stepped loading text
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) setState(() => _loadingText = 'Detecting facial features...');
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) setState(() => _loadingText = 'Classifying expressions...');
      });

      final result = await _photoService.analyzePhoto(_imageFile!);
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
    final text = "My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via PHOTO analysis 🧠";
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
            Text('Select Image Source',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFF48BB78),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF4A90D9),
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
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
            // Head context + hero
            Row(
              children: [
                Hero(
                  tag: 'icon_Photo',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF48BB78).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF48BB78), size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Photo Analysis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ).animate().fadeIn().slideX(begin: -0.2),

            const SizedBox(height: 24),

            // Image preview / Upload area
            GestureDetector(
              onTap: _loading ? null : _showSourcePicker,
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _imageFile != null
                        ? const Color(0xFF48BB78)
                        : AppColors.cardBorder,
                    width: _imageFile != null ? 1.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_imageFile!, fit: BoxFit.cover).animate().fadeIn(),
                          if (!_loading)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: _showSourcePicker,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.edit_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          if (_loading)
                             Container(
                               color: Colors.black.withValues(alpha: 0.5),
                               child: Center(
                                 child: const Icon(Icons.photo_camera_rounded, size: 64, color: Colors.white)
                                  .animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.2,1.2), duration: 600.ms, curve: Curves.easeInOut).shimmer(duration: 800.ms)
                               ),
                             )
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFF48BB78)
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.photo_camera_rounded,
                                size: 36, color: Color(0xFF48BB78)),
                          ).animate(target: _loading ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.15,1.15), duration: 600.ms).shimmer(duration: 800.ms),
                          const SizedBox(height: 16),
                          Text(
                            'Tap to select a photo',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: AppColors.textMid),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Camera or gallery • JPG, PNG (Max: 15MB)',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight),
                          ),
                        ],
                      ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

            const SizedBox(height: 16),

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
                  Icon(Icons.face_rounded,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Photo analysis detects facial expressions and body language to identify emotions.',
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
                      'Simulated — Photo analysis runs locally. Cloud API coming soon.',
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
                 onPressed: _imageFile == null ? _showSourcePicker : _analyse,
                 icon: const Icon(Icons.refresh_rounded),
                 label: Text(_imageFile == null ? 'Select Another File' : 'Try Again'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.surface,
                   foregroundColor: AppColors.primary,
                   side: BorderSide(color: AppColors.primary),
                 ),
               ).animate().fadeIn(),
            ] else ...[
               const SizedBox(height: 20),
               PrimaryButton(
                 label: _loading ? _loadingText : 'Analyse Photo',
                 onTap: _imageFile != null ? _analyse : null,
                 loading: _loading,
                 icon: Icons.search_rounded,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/text_emotion_service.dart';
import '../services/timeline_service.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../models/emotion_result.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/emotion_timeline_chart.dart';
import 'login_page.dart';

// ════════════════════════════════════════════════════════════
//  TEXT EMOTION PAGE
// ════════════════════════════════════════════════════════════
class TextEmotionPage extends StatefulWidget {
  const TextEmotionPage({super.key});

  @override
  State<TextEmotionPage> createState() => _TextEmotionPageState();
}

class _TextEmotionPageState extends State<TextEmotionPage> {
  final _ctrl = TextEditingController();
  final _textService = TextEmotionService();
  final _timelineService = TimelineService();
  final _alertsService = AlertsService();

  bool _loading = false;
  String _loadingText = 'Analyzing semantics...';
  EmotionResult? _result;
  String? _error;

  final List<String> _samples = [
    "I'm feeling absolutely thrilled about the project!",
    "This situation makes me feel really anxious and scared.",
    "I can't believe how unfair this is, I'm so angry.",
    "I feel quite neutral about the whole situation.",
    "Wow, I never expected that to happen!",
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

  Future<void> _analyse() async {
    if (_ctrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter some text to analyse.');
      return;
    }
    setState(() {
      _loading = true;
      _loadingText = 'Extracting semantics...';
      _error = null;
      _result = null;
    });

    try {
      // Simulate stepped loading text
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) setState(() => _loadingText = 'Running heuristic analysis...');
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) setState(() => _loadingText = 'Aggregating timeline results...');
      });

      final result = await _textService.analyzeText(_ctrl.text.trim());
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
    final text = "My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via TEXT analysis 🧠";
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, "Copied to clipboard!");
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Title Context
            Row(
              children: [
                Hero(
                  tag: 'icon_Text',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A90D9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.text_fields_rounded, color: Color(0xFF4A90D9), size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Text Analysis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ).animate().fadeIn().slideX(begin: -0.2),

            const SizedBox(height: 8),

            // Connected API badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF48BB78).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF48BB78).withValues(alpha: 0.25)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_done_rounded, size: 13, color: Color(0xFF48BB78)),
                  SizedBox(width: 6),
                  Text(
                    'Connected to Live API',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF48BB78)),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 16),

            // Input Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Enter Text',
                    subtitle: 'Type or paste text to detect emotions',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ctrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText:
                          'Start typing here...\nE.g. "I feel really happy today!"',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Character Counter
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('${_ctrl.text.length} characters', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                  ),

                  const SizedBox(height: 12),

                  // Sample texts
                  Text('Quick samples:',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _samples.map((s) {
                      return GestureDetector(
                        onTap: () => setState(() => _ctrl.text = s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            s.length > 30 ? '${s.substring(0, 30)}…' : s,
                            style: TextStyle(
                                fontSize: 11, color: AppColors.primary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: _error!),
                  ],
                ],
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),

            const SizedBox(height: 16),

            if (_loading)
               Center(
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     SizedBox(
                       width: 16, height: 16,
                       child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                     ),
                     const SizedBox(width: 12),
                     Text(_loadingText,
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                     ).animate(key: ValueKey(_loadingText)).fadeIn().shimmer(duration: 1200.ms),
                   ],
                 ),
               )
            else
               PrimaryButton(
                 label: 'Analyse Emotion',
                 onTap: _analyse,
                 loading: _loading,
                 icon: Icons.search_rounded,
               ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

            // Result
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

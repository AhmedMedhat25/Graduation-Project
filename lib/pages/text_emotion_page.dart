import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/emotion_result.dart';
import '../models/quota_status.dart';
import '../services/api_client.dart';
import '../services/quota_service.dart';
import '../services/text_emotion_service.dart';
import '../theme.dart';
import '../widgets/emotion_timeline_chart.dart';
import '../widgets/shared_widgets.dart';
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
  final TextEditingController _ctrl = TextEditingController();
  final TextEmotionService _textService = TextEmotionService();
  final QuotaService _quotaService = QuotaService();

  bool _loading = false;
  String _loadingText = 'Analyzing semantics...';
  EmotionResult? _result;
  QuotaTypeStatus? _quotaStatus;
  String? _error;

  final List<String> _samples = const [
    "I'm feeling absolutely thrilled about the project!",
    "This situation makes me feel really anxious and scared.",
    "I can't believe how unfair this is, I'm so angry.",
    "I feel quite neutral about the whole situation.",
    "Wow, I never expected that to happen!",
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _loadQuota();
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {
        if (_error != null && _ctrl.text.trim().isNotEmpty) {
          _error = null;
        }
        if (_result != null) {
          _result = null;
        }
      });
    }
  }

  int get _wordCount {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).length;
  }

  void _handleError(dynamic e) {
    if (e is SessionExpiredException) {
      _showReLoginDialog();
      return;
    }

    String msg = e.toString();

    msg = msg
        .replaceFirst('TextAnalysisException: ', '')
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
      setState(() => _quotaStatus = quota?.forType('text'));
    } catch (_) {}
  }

  Future<void> _analyse() async {
    final input = _ctrl.text.trim();

    if (input.isEmpty) {
      setState(() => _error = 'Please enter some text to analyse.');
      return;
    }

    // ── Quota gate ──
    try {
      final quota = await _quotaService.getQuota();
      if (mounted) setState(() => _quotaStatus = quota?.forType('text'));
      if (_quotaStatus?.isBlocked == true) {
        if (mounted) {
          setState(() => _error = 'Weekly text analysis limit reached. Resets next Monday.');
        }
        return;
      }
    } catch (_) {}

    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _loadingText = 'Extracting semantics...';
      _error = null;
      _result = null;
    });

    try {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) {
          setState(() => _loadingText = 'Running heuristic analysis...');
        }
      });

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) {
          setState(() => _loadingText = 'Aggregating timeline results...');
        }
      });

      final result = await _textService.analyzeText(input);


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

  void _applySample(String text) {
    HapticFeedback.selectionClick();
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
  }

  void _clearText() {
    HapticFeedback.lightImpact();
    _ctrl.clear();
    setState(() {
      _error = null;
      _result = null;
    });
  }

  void _shareResult() {
    if (_result == null) return;

    final text =
        'My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via TEXT analysis 🧠';

    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, 'Copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final hasInput = _ctrl.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopHeader().animate().fadeIn(duration: 350.ms).slideX(begin: -0.04, end: 0),
          const SizedBox(height: 18),
          _buildInputCard()
              .animate()
              .fadeIn(delay: 80.ms, duration: 350.ms)
              .slideY(begin: 0.06, end: 0),
          if (_quotaStatus != null) ...[
            const SizedBox(height: 12),
            QuotaProgressBar(
              label: 'Text',
              icon: Icons.text_fields_rounded,
              status: _quotaStatus!,
              unit: 'tokens',
            ).animate().fadeIn(delay: 120.ms, duration: 300.ms),
          ],
          if (_quotaStatus?.isBlocked == true) ...[
            const SizedBox(height: 12),
            const QuotaBlockedBanner(analysisType: 'Text'),
          ],
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _loading
                ? AnalysisLoadingPanel(
              key: const ValueKey('loading'),
              text: _loadingText,
            )
                : PrimaryButton(
              key: const ValueKey('button'),
              label: 'Analyse Emotion',
              onTap: _quotaStatus?.isBlocked == true ? null : _analyse,
              loading: _loading,
              icon: Icons.auto_awesome_rounded,
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
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
          if (!_loading && _result == null && !hasInput) ...[
            const SizedBox(height: 22),
            PremiumCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.tips_and_updates_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tip',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use a full sentence or short paragraph for more meaningful emotion analysis and timeline insights.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 180.ms, duration: 350.ms),
          ],
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        Hero(
          tag: 'icon_Text',
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.text_fields_rounded,
              color: AppColors.primary,
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
                'Text Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Detect emotion from typed or pasted text with a clean confidence breakdown.',
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

  Widget _buildInputCard() {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Enter Text',
                  subtitle: 'Type or paste content to detect emotional tone.',
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
          TextField(
            controller: _ctrl,
            maxLines: 6,
            minLines: 5,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText:
              'Start typing here...\n\nExample: "I feel really happy today because everything is going well."',
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                onPressed: _clearText,
                tooltip: 'Clear text',
                icon: Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              MetaPill(
                label: '${_ctrl.text.length} chars',
                icon: Icons.notes_rounded,
              ),
              const SizedBox(width: 8),
              MetaPill(
                label: '$_wordCount words',
                icon: Icons.short_text_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Quick samples',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _samples.map((sample) {
              final label =
              sample.length > 34 ? '${sample.substring(0, 34)}…' : sample;

              return _SampleChip(
                label: label,
                onTap: () => _applySample(sample),
              );
            }).toList(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            ErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

// _LoadingPanel, _StatusBadge, _MetaPill removed — using shared versions

class _SampleChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SampleChip({
    required this.label,
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
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
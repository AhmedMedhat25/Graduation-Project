import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/audio_emotion_service.dart';
import '../services/timeline_service.dart';
import '../services/alerts_service.dart';
import '../services/api_client.dart';
import '../models/emotion_result.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/emotion_timeline_chart.dart';
import 'login_page.dart';

// ════════════════════════════════════════════════════════════
//  AUDIO EMOTION PAGE
// ════════════════════════════════════════════════════════════
class AudioEmotionPage extends StatefulWidget {
  const AudioEmotionPage({super.key});

  @override
  State<AudioEmotionPage> createState() => _AudioEmotionPageState();
}

class _AudioEmotionPageState extends State<AudioEmotionPage> {
  final _audioService = AudioEmotionService();
  final _timelineService = TimelineService();
  final _alertsService = AlertsService();

  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  
  File? _audioFile;
  bool _loading = false;
  String _loadingText = 'Analysing Audio...';
  bool _isRecording = false;
  EmotionResult? _result;
  String? _error;

  // Playback state
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _isPlaying = s == PlayerState.playing);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
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

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      _handleSelectedFile(File(result.files.single.path!));
    }
  }

  void _handleSelectedFile(File file) {
    final sizeInBytes = file.lengthSync();
    final sizeInMb = sizeInBytes / (1024 * 1024);

    if (sizeInMb > 15) {
      setState(() {
        _error = 'File size must be under 15MB.';
        _audioFile = null;
        _result = null;
      });
      return;
    }

    _audioPlayer.stop();
    setState(() {
      _audioFile = file;
      _result = null;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
    });
  }

  // ── Recording Logic ──────────────────────────────────────
  Future<void> _startRecording() async {
    try {
      // Request microphone permission explicitly
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        if (mounted) {
          if (status.isPermanentlyDenied) {
            setState(() => _error =
                'Microphone permission permanently denied. Please enable it in Settings.');
            openAppSettings();
          } else {
            setState(() => _error = 'Microphone permission denied.');
          }
        }
        return;
      }

      // Build file path
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/emo_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // Configure recorder with reliable settings
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      );

      await _audioRecorder.start(config, path: filePath);
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Recording failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path != null) {
        _handleSelectedFile(File(path));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to stop recording: $e');
    }
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
            Text('Select Audio Source',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textDark)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.mic_rounded,
                    label: 'Record',
                    color: const Color(0xFF9F7AEA),
                    onTap: () {
                      Navigator.pop(context);
                      _startRecording();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.upload_file_rounded,
                    label: 'Upload',
                    color: const Color(0xFF4A90D9),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAudio();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _analyse() async {
    if (_audioFile == null) {
      setState(() => _error = 'Please select an audio file first.');
      return;
    }
    _audioPlayer.stop();
    setState(() {
      _loading = true;
      _loadingText = 'Extracting audio features...';
      _error = null;
      _result = null;
    });
    try {
      // Simulate stepped loading text
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _loading) setState(() => _loadingText = 'Running vocal analysis...');
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && _loading) setState(() => _loadingText = 'Aggregating segments...');
      });

      final result = await _audioService.analyzeAudio(_audioFile!);
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

  Future<void> _togglePlayback() async {
    if (_audioFile == null) return;
    
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(DeviceFileSource(_audioFile!.path));
    }
  }

  Future<void> _seekAudio(double seconds) async {
    await _audioPlayer.seek(Duration(milliseconds: (seconds * 1000).toInt()));
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _shareResult() {
    if (_result == null) return;
    final text = "My EMOTRA result: ${_result!.emotion.toUpperCase()} (${(_result!.confidence * 100).toStringAsFixed(1)}%) via AUDIO analysis 🧠";
    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, "Copied to clipboard!");
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
                  tag: 'icon_Audio',
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9F7AEA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.mic_rounded, color: Color(0xFF9F7AEA), size: 22),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Audio Analysis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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

            // Upload/Record area
            GestureDetector(
              onTap: _loading
                  ? null
                  : (_isRecording ? _stopRecording : _showSourcePicker),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isRecording
                        ? AppColors.error
                        : (_audioFile != null
                            ? const Color(0xFF9F7AEA)
                            : AppColors.cardBorder),
                    width: (_audioFile != null || _isRecording) ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: (_isRecording ? AppColors.error : const Color(0xFF9F7AEA))
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          size: 36,
                          color: _isRecording
                              ? AppColors.error
                              : const Color(0xFF9F7AEA)),
                    ).animate(
                      target: (_loading || _isRecording) ? 1 : 0,
                    )
                    .scale(begin: const Offset(1,1), end: const Offset(1.15, 1.15), duration: 600.ms, curve: Curves.easeInOut)
                    .shimmer(duration: 800.ms)
                    .callback(callback: (_) {
                      // No-op to allow target integration with repeat if we used custom controllers
                    }),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording
                          ? 'Recording... Tap to stop'
                          : (_audioFile != null
                              ? _audioFile!.path.split(Platform.pathSeparator).last
                              : 'Tap to record or upload audio'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: (_audioFile != null || _isRecording)
                            ? AppColors.textDark
                            : AppColors.textMid,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRecording
                          ? 'Capturing live audio'
                          : 'MP3, WAV, M4A, AAC supported (Max: 15MB)',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                    if (_audioFile != null && !_loading && !_isRecording) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _showSourcePicker,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: const Text('Change source'),
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
                  Icon(Icons.info_outline,
                      size: 16, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The audio emotion API analyses tone, pitch, and speech patterns to detect emotions.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMid),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

            if (_audioFile != null && !_isRecording && _error == null) ...[
              const SizedBox(height: 16),
              _AudioPreviewPlayer(
                isPlaying: _isPlaying,
                position: _position,
                total: _duration,
                onToggle: _togglePlayback,
                onSeek: _seekAudio,
                formatTime: _formatDuration,
              ).animate().fadeIn().slideY(begin: 0.1),
            ],

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
                 onPressed: _audioFile == null ? _pickAudio : _analyse,
                 icon: const Icon(Icons.refresh_rounded),
                 label: Text(_audioFile == null ? 'Select Another File' : 'Try Again'),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.surface,
                   foregroundColor: AppColors.primary,
                   side: BorderSide(color: AppColors.primary),
                 ),
               ).animate().fadeIn(),
            ] else ...[
               const SizedBox(height: 20),
                PrimaryButton(
                  label: _loading ? _loadingText : 'Analyse Audio',
                  onTap: (_audioFile != null && !_isRecording) ? _analyse : null,
                  loading: _loading,
                  icon: Icons.graphic_eq_rounded,
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
class _AudioPreviewPlayer extends StatelessWidget {
  final bool isPlaying;
  final Duration position;
  final Duration total;
  final VoidCallback onToggle;
  final Function(double) onSeek;
  final String Function(Duration) formatTime;

  const _AudioPreviewPlayer({
    required this.isPlaying,
    required this.position,
    required this.total,
    required this.onToggle,
    required this.onSeek,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final curSec = position.inSeconds.toDouble();
    final totSec = total.inSeconds.toDouble();
    final safeTotal = totSec > 0 ? totSec : 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: onToggle,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 24,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(48, 48),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlaying ? 'Playing Audio' : 'Ready to Review',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Review your clip before analysis',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatTime(position),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.1),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackShape: const RectangularSliderTrackShape(), // Flatter look
            ),
            child: Slider(
              value: curSec.clamp(0.0, safeTotal),
              max: safeTotal,
              onChanged: (v) => onSeek(v),
            ),
          ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

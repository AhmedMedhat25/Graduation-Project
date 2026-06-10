import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../models/emotion_result.dart';
import '../models/quota_status.dart';
import '../services/api_client.dart';
import '../services/audio_emotion_service.dart';
import '../services/quota_service.dart';
import '../theme.dart';
import '../widgets/emotion_timeline_chart.dart';
import '../widgets/shared_widgets.dart';
import 'login_page.dart';

class AudioEmotionPage extends StatefulWidget {
  const AudioEmotionPage({super.key});

  @override
  State<AudioEmotionPage> createState() => _AudioEmotionPageState();
}

class _AudioEmotionPageState extends State<AudioEmotionPage> {
  final AudioEmotionService _audioService = AudioEmotionService();
  final QuotaService _quotaService = QuotaService();

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  static const int _maxRecordingSeconds = 30;

  File? _audioFile;
  bool _loading = false;
  String _loadingText = 'Analysing audio...';
  bool _isRecording = false;
  EmotionResult? _result;
  String? _error;
  QuotaTypeStatus? _quotaStatus;

  bool _isPlaying = false;
  bool _playerReady = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  int _analysisRunId = 0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadQuota();
  }

  void _initPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;

      final cappedPosition =
      _duration > Duration.zero && position > _duration ? _duration : position;

      setState(() {
        _position = cappedPosition;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _analysisRunId++;
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleError(dynamic e) {
    if (e is SessionExpiredException) {
      _showReLoginDialog();
      return;
    }

    if (e is AudioAnalysisException) {
      final message = (e.cause?.toString().trim().isNotEmpty == true)
          ? e.cause.toString()
          : e.message;
      if (mounted) {
        setState(() => _error = message);
      }
      return;
    }

    final msg = e.toString().replaceFirst('Exception: ', '');

    if (msg.contains('Session expired')) {
      _showReLoginDialog();
      return;
    }

    if (mounted) {
      setState(() => _error = msg);
    }
  }

  void _showReLoginDialog() {
    showSessionExpiredDialog(context, const LoginPage());
  }

  Future<void> _pickAudio() async {
    HapticFeedback.selectionClick();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      await _handleSelectedFile(File(result.files.single.path!));
    }
  }

  Future<void> _preparePlayer(File file) async {
    await _audioPlayer.stop();

    if (mounted) {
      setState(() {
        _playerReady = false;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
      });
    }

    await _audioPlayer.setSource(DeviceFileSource(file.path));
    await _audioPlayer.seek(Duration.zero);

    final loadedDuration = await _audioPlayer.getDuration();

    if (!mounted) return;
    setState(() {
      _duration = loadedDuration ?? Duration.zero;
      _playerReady = true;
    });
  }

  Future<void> _handleSelectedFile(File file) async {
    try {
      final sizeInBytes = await file.length();
      final sizeInMb = sizeInBytes / (1024 * 1024);

      if (sizeInMb > 15) {
        if (!mounted) return;
        setState(() {
          _error = 'File size must be under 15MB.';
          _audioFile = null;
          _result = null;
          _position = Duration.zero;
          _duration = Duration.zero;
          _isPlaying = false;
          _playerReady = false;
        });
        return;
      }

      await _preparePlayer(file);

      if (!mounted) return;
      setState(() {
        _audioFile = file;
        _result = null;
        _error = null;
        _isPlaying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load audio file.';
        _audioFile = null;
        _result = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
        _playerReady = false;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      HapticFeedback.lightImpact();
      await _audioPlayer.stop();

      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
          _duration = Duration.zero;
          _playerReady = false;
        });
      }

      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        if (!mounted) return;

        if (status.isPermanentlyDenied) {
          setState(() {
            _error =
            'Microphone permission is permanently denied. Please enable it in Settings.';
          });
          await openAppSettings();
        } else {
          setState(() => _error = 'Microphone permission denied.');
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/emo_rec_${DateTime.now().millisecondsSinceEpoch}.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      await _audioRecorder.start(config, path: filePath);

      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _error = null;
        _result = null;
        _audioFile = null;
        _position = Duration.zero;
        _duration = Duration.zero;
        _isPlaying = false;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() => _recordingSeconds++);

        if (_recordingSeconds >= _maxRecordingSeconds) {
          timer.cancel();
          _stopRecording();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(
            () => _error =
        'Recording failed: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      HapticFeedback.mediumImpact();
      _recordingTimer?.cancel();

      final path = await _audioRecorder.stop();
      if (!mounted) return;

      setState(() => _isRecording = false);

      if (path != null) {
        if (_recordingSeconds < 2) {
          setState(() {
            _error = 'Recording too short. Please record at least 2 seconds.';
          });
          return;
        }

        await _handleSelectedFile(File(path));

        if (mounted && _duration == Duration.zero && _recordingSeconds > 0) {
          setState(() {
            _duration = Duration(seconds: _recordingSeconds);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to stop recording: $e');
    }
  }

  Future<void> _clearSelectedAudio() async {
    HapticFeedback.lightImpact();
    await _audioPlayer.stop();

    _playerReady = false;

    if (!mounted) return;
    setState(() {
      _audioFile = null;
      _result = null;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _recordingSeconds = 0;
    });
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return SafeArea(
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
                  'Select Audio Source',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Record live audio or upload an existing file.',
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
                        icon: Icons.mic_rounded,
                        label: 'Record',
                        subtitle: 'Capture a new clip',
                        color: AppColors.fearful,
                        onTap: () {
                          Navigator.pop(context);
                          _startRecording();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SourceOption(
                        icon: Icons.upload_file_rounded,
                        label: 'Upload',
                        subtitle: 'Choose from device',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(context);
                          _pickAudio();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadQuota() async {
    try {
      final quota = await _quotaService.getQuota();
      final audioQuota = quota?.forType('audio');

      if (!mounted) return;
      setState(() => _quotaStatus = audioQuota);
    } catch (e) {
      debugPrint('⚠️ Failed to load audio quota: $e');
    }
  }

  void _scheduleLoadingText(
      int runId,
      Duration delay,
      String text,
      ) {
    Future.delayed(delay, () {
      if (!mounted || !_loading || runId != _analysisRunId) return;
      setState(() => _loadingText = text);
    });
  }

  Future<void> _analyse() async {
    if (_loading) return;

    final selectedFile = _audioFile;
    if (selectedFile == null) {
      setState(() => _error = 'Please select an audio file first.');
      return;
    }

    try {
      final quota = await _quotaService.getQuota();
      final audioQuota = quota?.forType('audio');

      if (mounted) {
        setState(() => _quotaStatus = audioQuota);
      }

      int fileDurationSec;
      if (_duration.inSeconds > 0) {
        fileDurationSec = _duration.inSeconds;
      } else if (_recordingSeconds > 0) {
        fileDurationSec = _recordingSeconds;
      } else {
        final bytes = await selectedFile.length();
        final isWav = selectedFile.path.toLowerCase().endsWith('.wav');
        fileDurationSec = (bytes / (isWav ? 32000 : 16000)).ceil();
      }

      final wouldExceed =
          audioQuota != null && fileDurationSec > audioQuota.remaining;

      if (audioQuota?.isBlocked == true || wouldExceed) {
        if (mounted) {
          setState(() => _error =
          'Weekly audio analysis limit reached. Resets every Monday at 00:00 UTC.');
        }
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Audio quota check failed: $e');
    }

    final fileExists = await selectedFile.exists();
    final fileSize = fileExists ? await selectedFile.length() : 0;

    if (!fileExists || fileSize == 0) {
      setState(() => _error =
      'Audio file is empty or missing. Please re-record.');
      return;
    }

    final ext = selectedFile.path.toLowerCase();
    final isWav = ext.endsWith('.wav');

    if (isWav && fileSize < 10000) {
      setState(() => _error =
      'Recording is too quiet or silent. Please speak clearly and try again.');
      return;
    }

    if (!isWav && fileSize < 5000) {
      setState(() => _error =
      'File appears too small or corrupted. Please try again.');
      return;
    }

    HapticFeedback.lightImpact();
    await _audioPlayer.stop();

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    }

    final runId = ++_analysisRunId;

    setState(() {
      _loading = true;
      _loadingText = 'Extracting audio features...';
      _error = null;
      _result = null;
    });

    _scheduleLoadingText(
      runId,
      const Duration(milliseconds: 600),
      'Running vocal analysis...',
    );
    _scheduleLoadingText(
      runId,
      const Duration(milliseconds: 1400),
      'Aggregating segments...',
    );
    _scheduleLoadingText(
      runId,
      const Duration(milliseconds: 2500),
      'Analysing emotions...',
    );

    try {
      final result = await _audioService.analyzeAudio(selectedFile);

      if (!mounted || runId != _analysisRunId) return;
      setState(() => _result = result);

      await _loadQuota();
    } catch (e) {
      if (mounted && runId == _analysisRunId) {
        _handleError(e);
      }
    } finally {
      if (mounted && runId == _analysisRunId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _togglePlayback() async {
    final selectedFile = _audioFile;
    if (selectedFile == null || _loading || _isRecording) return;

    try {
      if (!_playerReady) {
        await _preparePlayer(selectedFile);
      }

      if (_isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      final hasProgress =
          _position > Duration.zero &&
              _duration > Duration.zero &&
              _position < _duration;

      if (!hasProgress) {
        await _audioPlayer.seek(Duration.zero);
        if (mounted) {
          setState(() => _position = Duration.zero);
        }
      }

      await _audioPlayer.resume();
    } catch (e) {
      _playerReady = false;
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _error = 'Failed to play audio preview.';
      });
    }
  }

  Future<void> _seekAudio(double seconds) async {
    if (_audioFile == null || _loading || _isRecording) return;

    try {
      if (!_playerReady && _audioFile != null) {
        await _preparePlayer(_audioFile!);
      }

      final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 0;
      final targetMs = (seconds * 1000).round().clamp(0, maxMs);
      final target = Duration(milliseconds: targetMs);

      await _audioPlayer.seek(target);

      if (mounted) {
        setState(() => _position = target);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to seek audio.');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<String> _formatFileSize(File file) async {
    final bytes = await file.length();
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _fileName(File file) {
    return file.path.split(Platform.pathSeparator).last;
  }

  void _copyResult() {
    if (_result == null) return;

    final text =
        'My EMOTRA result: ${_result!.emotion.toUpperCase()} '
        '(${(_result!.confidence * 100).toStringAsFixed(1)}%) '
        'via AUDIO analysis 🧠';

    Clipboard.setData(ClipboardData(text: text));
    showAppSnackbar(context, 'Copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final hasAudio = _audioFile != null;

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
          _buildSourceCard()
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
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The audio emotion engine analyzes vocal tone, pitch, and speech patterns to estimate emotional state.',
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
          if (hasAudio && !_isRecording && _error == null) ...[
            const SizedBox(height: 16),
            _AudioPreviewPlayer(
              fileName: _fileName(_audioFile!),
              isPlaying: _isPlaying,
              position: _position,
              total: _duration,
              onToggle: _togglePlayback,
              onSeek: _seekAudio,
              formatTime: _formatDuration,
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),
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
              key: const ValueKey('audio-loading'),
              text: _loadingText,
            )
                : PrimaryButton(
              key: const ValueKey('audio-button'),
              label: 'Analyse Audio',
              onTap: (_quotaStatus?.isBlocked == true)
                  ? null
                  : (hasAudio && !_isRecording) ? _analyse : null,
              loading: _loading,
              icon: Icons.graphic_eq_rounded,
            ),
          ).animate().fadeIn(delay: 140.ms, duration: 300.ms),
          if (_quotaStatus != null) ...[
            const SizedBox(height: 12),
            QuotaProgressBar(
              label: 'Audio',
              icon: Icons.mic_rounded,
              status: _quotaStatus!,
              unit: 'seconds',
            ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
          ],
          if (_quotaStatus?.isBlocked == true) ...[
            const SizedBox(height: 12),
            const QuotaBlockedBanner(analysisType: 'Audio'),
          ],
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
                  onTap: _copyResult,
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
          tag: 'icon_Audio',
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.fearful.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.fearful.withValues(alpha: 0.14),
              ),
            ),
            child: Icon(
              Icons.mic_rounded,
              color: AppColors.fearful,
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
                'Audio Analysis',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload or record a voice clip to detect emotion from vocal patterns.',
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

  Widget _buildSourceCard() {
    final hasAudio = _audioFile != null;
    final accentColor = _isRecording
        ? AppColors.error
        : hasAudio
        ? AppColors.fearful
        : AppColors.primary;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Audio Source',
                  subtitle: 'Record live audio or upload a supported file.',
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
              onTap: _loading
                  ? null
                  : (_isRecording ? _stopRecording : _showSourcePicker),
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isRecording || hasAudio
                        ? accentColor.withValues(alpha: 0.45)
                        : AppColors.borderSoft,
                    width: _isRecording || hasAudio ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording
                            ? Icons.stop_rounded
                            : hasAudio
                            ? Icons.audiotrack_rounded
                            : Icons.mic_rounded,
                        size: 34,
                        color: accentColor,
                      ),
                    )
                        .animate(
                      target: (_loading || _isRecording) ? 1 : 0,
                      onPlay: (controller) =>
                          controller.repeat(reverse: true),
                    )
                        .scaleXY(
                      begin: 1,
                      end: 1.05,
                      duration: 900.ms,
                      curve: Curves.easeInOut,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRecording
                          ? 'Recording... tap to stop'
                          : hasAudio
                          ? _fileName(_audioFile!)
                          : 'Tap to record or upload audio',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: hasAudio || _isRecording
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isRecording
                          ? 'Capturing live audio input'
                          : 'MP3, WAV, M4A, AAC supported • Max 15MB',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isRecording) ...[
                      const SizedBox(height: 14),
                      MetaPill(
                        label:
                        'Recording ${_formatDuration(Duration(seconds: _recordingSeconds))}',
                        icon: Icons.fiber_manual_record_rounded,
                      ),
                    ],
                    if (hasAudio && !_isRecording) ...[
                      const SizedBox(height: 14),
                      FutureBuilder<String>(
                        future: _formatFileSize(_audioFile!),
                        builder: (context, snapshot) {
                          final sizeLabel = snapshot.data ?? '...';
                          return Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              MetaPill(
                                label: sizeLabel,
                                icon: Icons.sd_storage_rounded,
                              ),
                              MetaPill(
                                label: _duration > Duration.zero
                                    ? _formatDuration(_duration)
                                    : (_recordingSeconds > 0
                                    ? _formatDuration(
                                    Duration(seconds: _recordingSeconds))
                                    : 'Duration loading...'),
                                icon: Icons.timer_outlined,
                              ),
                              const MetaPill(
                                label: 'Ready to analyze',
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            ],
                          );
                        },
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
                            label: const Text('Change source'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _clearSelectedAudio,
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
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

class _AudioPreviewPlayer extends StatelessWidget {
  final String fileName;
  final bool isPlaying;
  final Duration position;
  final Duration total;
  final VoidCallback onToggle;
  final ValueChanged<double> onSeek;
  final String Function(Duration) formatTime;

  const _AudioPreviewPlayer({
    required this.fileName,
    required this.isPlaying,
    required this.position,
    required this.total,
    required this.onToggle,
    required this.onSeek,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = total.inMilliseconds;
    final positionMs = position.inMilliseconds.clamp(
      0,
      totalMs > 0 ? totalMs : 0,
    );

    final currentSeconds = positionMs / 1000.0;
    final totalSeconds = totalMs > 0 ? totalMs / 1000.0 : 1.0;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 26,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlaying ? 'Playing audio...' : 'Audio preview',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatTime(Duration(milliseconds: positionMs)),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withValues(alpha: 0.1),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: currentSeconds.clamp(0.0, totalSeconds),
              max: totalSeconds,
              onChanged: totalMs > 0 ? onSeek : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatTime(Duration(milliseconds: positionMs)),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  formatTime(total),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
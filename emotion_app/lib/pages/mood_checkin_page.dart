import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../models/emotion_result.dart';
import '../services/timeline_service.dart';

// ════════════════════════════════════════════════════════════
//  MOOD CHECK-IN PAGE
// ════════════════════════════════════════════════════════════
class MoodCheckinPage extends StatefulWidget {
  final VoidCallback onComplete;

  const MoodCheckinPage({super.key, required this.onComplete});

  @override
  State<MoodCheckinPage> createState() => _MoodCheckinPageState();

  /// Returns true if the user hasn't checked in today yet.
  static Future<bool> shouldShowToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckin = prefs.getString('last_mood_checkin');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastCheckin != today;
  }
}

class _MoodCheckinPageState extends State<MoodCheckinPage> {
  final _timelineService = TimelineService();
  final _noteCtrl = TextEditingController();

  int? _selectedIndex;
  bool _saving = false;

  final List<Map<String, dynamic>> _moods = [
    {
      'emoji': '😊',
      'emotion': 'joy',
      'label': 'Happy',
      'color': const Color(0xFFFFD700)
    },
    {
      'emoji': '😢',
      'emotion': 'sadness',
      'label': 'Sad',
      'color': const Color(0xFF4A90D9)
    },
    {
      'emoji': '😠',
      'emotion': 'anger',
      'label': 'Angry',
      'color': const Color(0xFFE53E3E)
    },
    {
      'emoji': '😨',
      'emotion': 'fear',
      'label': 'Anxious',
      'color': const Color(0xFF9F7AEA)
    },
    {
      'emoji': '😲',
      'emotion': 'surprise',
      'label': 'Surprised',
      'color': const Color(0xFFED8936)
    },
    {
      'emoji': '🤢',
      'emotion': 'disgust',
      'label': 'Disgusted',
      'color': const Color(0xFF48BB78)
    },
    {
      'emoji': '😐',
      'emotion': 'neutral',
      'label': 'Neutral',
      'color': const Color(0xFF9AA5B4)
    },
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedIndex == null) return;
    if (_saving) return;
    setState(() => _saving = true);

    HapticFeedback.mediumImpact();

    final mood = _moods[_selectedIndex!];
    final emotion = mood['emotion'] as String;

    // Build confidence map — selected emotion at 1.0, rest zero
    final allEmotions = <String, double>{
      for (final m in _moods) m['emotion'] as String: 0.0,
    };
    allEmotions[emotion] = 1.0;

    final result = EmotionResult(
      emotion: emotion,
      confidence: 1.0,
      allEmotions: allEmotions,
      timestamp: DateTime.now(),
      // Use 'checkin' type — dashboard handles it like any other entry
      type: 'checkin',
    );

    // Persist check-in date to suppress today's prompt
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('last_mood_checkin', today);

    await _timelineService.saveResult(result);

    if (mounted) widget.onComplete();
  }

  Future<void> _skip() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('last_mood_checkin', today);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning ☀️'
        : hour < 17
            ? 'Good afternoon 🌤️'
            : 'Good evening 🌙';

    final selected =
        _selectedIndex != null ? _moods[_selectedIndex!] : null;
    final moodColor =
        selected != null ? selected['color'] as Color : AppColors.primary;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              moodColor.withValues(alpha: 0.07),
              AppColors.background,
              AppColors.accent.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // ── Greeting ─────────────────────────────────
                Text(
                  greeting,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(duration: 500.ms),

                const SizedBox(height: 8),

                Text(
                  'Daily Check-in',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                    letterSpacing: -0.5,
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),

                const SizedBox(height: 10),

                Text(
                  'How are you feeling right now?',
                  style: TextStyle(fontSize: 16, color: AppColors.textMid),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 40),

                // ── Mood Grid ────────────────────────────────
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: _moods.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    final isSelected = _selectedIndex == i;
                    final color = m['color'] as Color;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedIndex = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutBack,
                        width: isSelected ? 90 : 82,
                        height: isSelected ? 90 : 82,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.13)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? color
                                : AppColors.cardBorder,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? color.withValues(alpha: 0.28)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: isSelected ? 18 : 8,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              m['emoji'],
                              style: TextStyle(
                                  fontSize: isSelected ? 34 : 30),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m['label'],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: isSelected
                                    ? color
                                    : AppColors.textMid,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (500 + i * 70).ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          duration: 380.ms,
                          curve: Curves.easeOutBack,
                        );
                  }).toList(),
                ),

                // ── Optional note ────────────────────────────
                if (_selectedIndex != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: moodColor.withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      maxLength: 200,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textDark),
                      decoration: InputDecoration(
                        hintText: 'Add a note (optional)…',
                        hintStyle:
                            TextStyle(color: AppColors.textLight, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        counterStyle:
                            TextStyle(color: AppColors.textLight, fontSize: 11),
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2),
                ],

                const SizedBox(height: 32),

                // ── Log Mood button ──────────────────────────
                AnimatedOpacity(
                  opacity: _selectedIndex != null ? 1.0 : 0.35,
                  duration: const Duration(milliseconds: 250),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selectedIndex != null && !_saving
                          ? _save
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: moodColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: _selectedIndex != null ? 4 : 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _selectedIndex != null
                                  ? 'Log ${_moods[_selectedIndex!]['label']} Mood'
                                  : 'Select a mood first',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),

                const SizedBox(height: 16),

                // ── Skip button ──────────────────────────────
                TextButton.icon(
                  onPressed: _skip,
                  icon: Icon(Icons.skip_next_rounded,
                      size: 18, color: AppColors.textLight),
                  label: Text(
                    'Skip for today',
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500),
                  ),
                ).animate().fadeIn(delay: 1000.ms),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../models/emotion_result.dart';
import '../services/timeline_service.dart';

// ════════════════════════════════════════════════════════════
//  MOOD CHECK-IN PAGE - Polished UX
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
    final today = DateTime.now().toUtc().add(const Duration(hours: 3)).toIso8601String().substring(0, 10);
    return lastCheckin != today;
  }
}

class _MoodCheckinPageState extends State<MoodCheckinPage> {
  final _timelineService = TimelineService();
  final _noteCtrl = TextEditingController();

  int? _selectedIndex;
  bool _saving = false;

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😁', 'emotion': 'joy', 'label': 'Great', 'color': const Color(0xFFFFD700)},
    {'emoji': '🙂', 'emotion': 'neutral', 'label': 'Good', 'color': const Color(0xFF48BB78)},
    {'emoji': '😐', 'emotion': 'neutral', 'label': 'Okay', 'color': const Color(0xFF9AA5B4)},
    {'emoji': '😔', 'emotion': 'sadness', 'label': 'Sad', 'color': const Color(0xFF4A90D9)},
    {'emoji': '😫', 'emotion': 'fear', 'label': 'Anxious', 'color': const Color(0xFF9F7AEA)},
    {'emoji': '😠', 'emotion': 'anger', 'label': 'Angry', 'color': const Color(0xFFE53E3E)},
  ];

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedIndex == null || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final mood = _moods[_selectedIndex!];
    final emotion = mood['emotion'] as String;

    final allEmotions = <String, double>{
      for (final m in _moods) m['emotion'] as String: 0.0,
    };
    allEmotions[emotion] = 1.0;

    final result = EmotionResult(
      emotion: emotion,
      confidence: 1.0,
      allEmotions: allEmotions,
      timestamp: DateTime.now().toUtc().add(const Duration(hours: 3)),
      type: 'checkin',
    );

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('last_mood_checkin', today);

    await _timelineService.saveResult(result);

    if (mounted) widget.onComplete();
  }

  Future<void> _skip() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toUtc().add(const Duration(hours: 3)).toIso8601String().substring(0, 10);
    await prefs.setString('last_mood_checkin', today);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final cairoTime = DateTime.now().toUtc().add(const Duration(hours: 3));
    final hour = cairoTime.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final selected = _selectedIndex != null ? _moods[_selectedIndex!] : null;
    final moodColor = selected != null ? selected['color'] as Color : AppColors.primary;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              moodColor.withValues(alpha: 0.15),
              AppColors.background,
              AppColors.background,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),

                      // ── Greeting & Title ─────────────────────────────────
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textMid,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),

                      const SizedBox(height: 6),

                      Text(
                        'How are you feeling?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.1),

                      const SizedBox(height: 40),

                      // ── Mood Grid ────────────────────────────────
                      Wrap(
                        spacing: 16,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: _moods.asMap().entries.map((entry) {
                          final i = entry.key;
                          final m = entry.value;
                          final isSelected = _selectedIndex == i;
                          final color = m['color'] as Color;

                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() => _selectedIndex = i);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              width: isSelected ? 95 : 85,
                              height: isSelected ? 105 : 95,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color.withValues(alpha: 0.15)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected
                                      ? color
                                      : AppColors.cardBorder.withValues(alpha: 0.5),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    )
                                  else
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedScale(
                                    scale: isSelected ? 1.2 : 1.0,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutBack,
                                    child: Text(
                                      m['emoji'],
                                      style: const TextStyle(fontSize: 36),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    m['label'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected ? color : AppColors.textMid,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(delay: (400 + i * 50).ms).scale(
                            begin: const Offset(0.8, 0.8),
                            curve: Curves.easeOutBack,
                          );
                        }).toList(),
                      ),

                      // ── Optional Note ────────────────────────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: _selectedIndex != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 32),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: moodColor.withValues(alpha: 0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _noteCtrl,
                                    maxLines: 2,
                                    maxLength: 150,
                                    style: TextStyle(fontSize: 14, color: AppColors.textDark),
                                    decoration: InputDecoration(
                                      hintText: 'Add a note (optional)...',
                                      hintStyle: TextStyle(color: AppColors.textLight, fontSize: 14),
                                      border: InputBorder.none,
                                      counterStyle: TextStyle(color: AppColors.textLight, fontSize: 11),
                                    ),
                                  ),
                                ).animate().fadeIn().slideY(begin: 0.1),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom Action Area ──────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.background.withValues(alpha: 0.0),
                      AppColors.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: _selectedIndex != null ? 1.0 : 0.4,
                      duration: const Duration(milliseconds: 300),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _selectedIndex != null && !_saving ? _save : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: moodColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.surface,
                            disabledForegroundColor: AppColors.textLight,
                            elevation: _selectedIndex != null ? 8 : 0,
                            shadowColor: moodColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                )
                              : Text(
                                  _selectedIndex != null
                                      ? 'Log ${_moods[_selectedIndex!]['label']}'
                                      : 'Select a mood',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),
                    
                    const SizedBox(height: 12),
                    
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textLight,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Skip for today',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ).animate().fadeIn(delay: 1000.ms),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

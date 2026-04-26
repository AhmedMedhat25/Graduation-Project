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

  // Helper logic to see if we should show it today
  static Future<bool> shouldShowToday() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckin = prefs.getString('last_mood_checkin');
    
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return lastCheckin != today;
  }
}

class _MoodCheckinPageState extends State<MoodCheckinPage> {
  final _timelineService = TimelineService();
  int? _selectedIndex;

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😊', 'emotion': 'happy', 'label': 'Happy', 'color': const Color(0xFFFFD700)},
    {'emoji': '😢', 'emotion': 'sad', 'label': 'Sad', 'color': const Color(0xFF4A90D9)},
    {'emoji': '😠', 'emotion': 'angry', 'label': 'Angry', 'color': const Color(0xFFE53E3E)},
    {'emoji': '😨', 'emotion': 'fearful', 'label': 'Anxious', 'color': const Color(0xFF9F7AEA)},
    {'emoji': '😲', 'emotion': 'surprised', 'label': 'Surprised', 'color': const Color(0xFFED8936)},
    {'emoji': '🤢', 'emotion': 'disgusted', 'label': 'Disgusted', 'color': const Color(0xFF48BB78)},
    {'emoji': '😐', 'emotion': 'neutral', 'label': 'Neutral', 'color': const Color(0xFF9AA5B4)},
  ];

  Future<void> _selectMood(String emotion, int index) async {
    HapticFeedback.mediumImpact();
    setState(() => _selectedIndex = index);

    // Small delay for the animation to play
    await Future.delayed(const Duration(milliseconds: 400));

    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString('last_mood_checkin', today);

    // Save checkin in timeline
    final result = EmotionResult(
      emotion: emotion,
      confidence: 1.0,
      allEmotions: {emotion: 1.0},
      timestamp: DateTime.now(),
      type: 'checkin', // new checkin type
    );
    await _timelineService.saveResult(result);

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning ☀️';
    } else if (hour < 17) {
      greeting = 'Good afternoon 🌤️';
    } else {
      greeting = 'Good evening 🌙';
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.background,
              AppColors.accent.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Greeting
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

                const SizedBox(height: 12),

                Text(
                  'How are you feeling right now?',
                  style: TextStyle(fontSize: 16, color: AppColors.textMid),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 48),

                // Mood Grid
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: _moods.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    final isSelected = _selectedIndex == i;
                    final moodColor = m['color'] as Color;

                    return GestureDetector(
                      onTap: () => _selectMood(m['emotion'], i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        width: isSelected ? 88 : 82,
                        height: isSelected ? 88 : 82,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? moodColor.withValues(alpha: 0.12)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? moodColor : AppColors.cardBorder,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: moodColor.withValues(alpha: 0.25),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  )
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(m['emoji'],
                                style: TextStyle(fontSize: isSelected ? 34 : 30)),
                            const SizedBox(height: 4),
                            Text(m['label'],
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? moodColor
                                        : AppColors.textMid)),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (500 + (i * 80)).ms).scale(
                          begin: const Offset(0.8, 0.8),
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        );
                  }).toList(),
                ),

                const Spacer(flex: 2),

                // Skip button
                TextButton.icon(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final prefs = await SharedPreferences.getInstance();
                    final today = DateTime.now().toIso8601String().substring(0, 10);
                    await prefs.setString('last_mood_checkin', today);
                    widget.onComplete();
                  },
                  icon: Icon(Icons.skip_next_rounded,
                      size: 18, color: AppColors.textLight),
                  label: Text('Skip for today',
                      style: TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w500)),
                ).animate().fadeIn(delay: 1200.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

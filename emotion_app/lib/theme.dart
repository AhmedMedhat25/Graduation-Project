import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_service.dart';

// CHANGED: Refactored AppColors to support dynamic themes
class ThemeColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textDark;
  final Color textMid;
  final Color textLight;
  final Color cardBorder;
  final Color success = const Color(0xFF48BB78);
  final Color warning = const Color(0xFFED8936);
  final Color error = const Color(0xFFE53E3E);

  const ThemeColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textDark,
    required this.textMid,
    required this.textLight,
    required this.cardBorder,
  });
}

class AppColors {
  // Emotion colors remain constant
  static const Color happy = Color(0xFFFFD700);
  static const Color sad = Color(0xFF4A90D9);
  static const Color angry = Color(0xFFE53E3E);
  static const Color fearful = Color(0xFF9F7AEA);
  static const Color surprised = Color(0xFFED8936);
  static const Color disgusted = Color(0xFF48BB78);
  static const Color neutral = Color(0xFF9AA5B4);
  
  static const Color success = Color(0xFF48BB78);
  static const Color warning = Color(0xFFED8936);
  static const Color error = Color(0xFFE53E3E);

  static ThemeColors get _current {
    switch (ThemeService.themeNotifier.value.toLowerCase()) {
      case 'dark':
        return _dark;
      case 'ocean':
        return _ocean;
      case 'sunset':
        return _sunset;
      default:
        return _light;
    }
  }

  static Color get primary => _current.primary;
  static Color get secondary => _current.secondary;
  static Color get accent => _current.accent;
  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get textDark => _current.textDark;
  static Color get textMid => _current.textMid;
  static Color get textLight => _current.textLight;
  static Color get cardBorder => _current.cardBorder;

  // Definitions
  static const _light = ThemeColors(
    primary: Color(0xFF2D3A8C),
    secondary: Color(0xFF4A90D9),
    accent: Color(0xFF6C63FF),
    background: Color(0xFFF4F6FC),
    surface: Color(0xFFFFFFFF),
    textDark: Color(0xFF1A1F36),
    textMid: Color(0xFF4A5568),
    textLight: Color(0xFF9AA5B4),
    cardBorder: Color(0xFFE2E8F0),
  );

  static const _dark = ThemeColors(
    primary: Color(0xFF6C63FF),
    secondary: Color(0xFF4A90D9),
    accent: Color(0xFF2D3A8C),
    background: Color(0xFF0F121C),
    surface: Color(0xFF1E2130),
    textDark: Color(0xFFF4F6FC),
    textMid: Color(0xFFA0AEC0),
    textLight: Color(0xFF718096),
    cardBorder: Color(0xFF2D3748),
  );

  static const _ocean = ThemeColors(
    primary: Color(0xFF0077B6),
    secondary: Color(0xFF00B4D8),
    accent: Color(0xFF03045E),
    background: Color(0xFFE0FBFC),
    surface: Color(0xFFFFFFFF),
    textDark: Color(0xFF012A4A),
    textMid: Color(0xFF01497C),
    textLight: Color(0xFF2A6F97),
    cardBorder: Color(0xFF90E0EF),
  );

  static const _sunset = ThemeColors(
    primary: Color(0xFFE63946),
    secondary: Color(0xFFF4A261),
    accent: Color(0xFFE76F51),
    background: Color(0xFFFFF3E0),
    surface: Color(0xFFFFFFFF),
    textDark: Color(0xFF3E2723),
    textMid: Color(0xFF5D4037),
    textLight: Color(0xFF8D6E63),
    cardBorder: Color(0xFFFFCC80),
  );
}

// CHANGED: AppTheme now dynamically returns the correct ThemeData based on ThemeService
class AppTheme {
  static ThemeData get theme {
    final colors = AppColors._current;
    final isDark = ThemeService.themeNotifier.value.toLowerCase() == 'dark';

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        surface: colors.surface,
      ),
      scaffoldBackgroundColor: colors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: colors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: colors.textDark),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.cardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: colors.textLight),
        labelStyle: TextStyle(color: colors.textMid),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 4,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: colors.textDark,
        displayColor: colors.textDark,
      ),
    );
  }
}

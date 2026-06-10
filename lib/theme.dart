import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/theme_service.dart';

class ThemeColors {
  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color accent;

  final Color background;
  final Color surface;
  final Color surfaceSoft;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color border;
  final Color borderSoft;
  final Color shadow;

  final Color gradientStart;
  final Color gradientEnd;

  const ThemeColors({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderSoft,
    required this.shadow,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

class AppColors {
  // Emotion colors
  static const Color happy = Color(0xFFFFD700);
  static const Color sad = Color(0xFF4A90D9);
  static const Color angry = Color(0xFFE53E3E);
  static const Color fearful = Color(0xFF9F7AEA);
  static const Color surprised = Color(0xFFED8936);
  static const Color disgusted = Color(0xFF48BB78);
  static const Color neutral = Color(0xFF9AA5B4);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  static ThemeColors get _current {
    switch (ThemeService.themeNotifier.value.toLowerCase()) {
      case 'dark':
        return _dark;
      case 'ocean':
        return _ocean;
      case 'sunset':
        return _sunset;
      case 'forest':
        return _forest;
      default:
        return _light;
    }
  }

  static Color get primary => _current.primary;
  static Color get primaryDark => _current.primaryDark;
  static Color get secondary => _current.secondary;
  static Color get accent => _current.accent;

  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get surfaceSoft => _current.surfaceSoft;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textMuted => _current.textMuted;

  static Color get border => _current.border;
  static Color get borderSoft => _current.borderSoft;
  static Color get shadow => _current.shadow;

  static Color get gradientStart => _current.gradientStart;
  static Color get gradientEnd => _current.gradientEnd;

  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  // Premium default light theme
  static const ThemeColors _light = ThemeColors(
    primary: Color(0xFF5B5FEF),
    primaryDark: Color(0xFF4347D9),
    secondary: Color(0xFF7C84FF),
    accent: Color(0xFF14B8A6),
    background: Color(0xFFF6F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF9CA3AF),
    border: Color(0xFFE5E7EB),
    borderSoft: Color(0xFFF1F5F9),
    shadow: Color(0xFF0F172A),
    gradientStart: Color(0xFF5B5FEF),
    gradientEnd: Color(0xFF7C3AED),
  );

  static const ThemeColors _dark = ThemeColors(
    primary: Color(0xFF7C84FF),
    primaryDark: Color(0xFF5B5FEF),
    secondary: Color(0xFF22D3EE),
    accent: Color(0xFF8B5CF6),
    background: Color(0xFF0B1020),
    surface: Color(0xFF12192B),
    surfaceSoft: Color(0xFF182133),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    border: Color(0xFF243045),
    borderSoft: Color(0xFF1B2435),
    shadow: Color(0xFF000000),
    gradientStart: Color(0xFF7C84FF),
    gradientEnd: Color(0xFF8B5CF6),
  );

  static const ThemeColors _ocean = ThemeColors(
    primary: Color(0xFF0077B6),
    primaryDark: Color(0xFF005F8F),
    secondary: Color(0xFF00B4D8),
    accent: Color(0xFF48CAE4),
    background: Color(0xFFF2FBFD),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF7FDFF),
    textPrimary: Color(0xFF0B2239),
    textSecondary: Color(0xFF34506B),
    textMuted: Color(0xFF6B8AA6),
    border: Color(0xFFD5EAF2),
    borderSoft: Color(0xFFEDF7FB),
    shadow: Color(0xFF0B2239),
    gradientStart: Color(0xFF0077B6),
    gradientEnd: Color(0xFF00B4D8),
  );

  static const ThemeColors _sunset = ThemeColors(
    primary: Color(0xFFE76F51),
    primaryDark: Color(0xFFD65A3C),
    secondary: Color(0xFFF4A261),
    accent: Color(0xFFE9C46A),
    background: Color(0xFFFFF8F4),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFFFFBF8),
    textPrimary: Color(0xFF3E2723),
    textSecondary: Color(0xFF6D4C41),
    textMuted: Color(0xFFA1887F),
    border: Color(0xFFF1D8CF),
    borderSoft: Color(0xFFFFEEE8),
    shadow: Color(0xFF3E2723),
    gradientStart: Color(0xFFE76F51),
    gradientEnd: Color(0xFFF4A261),
  );

  static const ThemeColors _forest = ThemeColors(
    primary: Color(0xFF2D6A4F),
    primaryDark: Color(0xFF1F513B),
    secondary: Color(0xFF40916C),
    accent: Color(0xFF74C69D),
    background: Color(0xFFF4FBF6),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF7FCF8),
    textPrimary: Color(0xFF102A1C),
    textSecondary: Color(0xFF355B47),
    textMuted: Color(0xFF6B8F7C),
    border: Color(0xFFD8ECDD),
    borderSoft: Color(0xFFEDF7F0),
    shadow: Color(0xFF102A1C),
    gradientStart: Color(0xFF2D6A4F),
    gradientEnd: Color(0xFF40916C),
  );
}

class AppTheme {
  static bool get _isDark =>
      ThemeService.themeNotifier.value.toLowerCase() == 'dark';

  static ThemeData get theme {
    final colors = AppColors._current;
    final brightness = _isDark ? Brightness.dark : Brightness.light;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: colors.primary,
      brightness: brightness,
    ).copyWith(
      primary: colors.primary,
      secondary: colors.secondary,
      surface: colors.surface,
      error: AppColors.error,
      outline: colors.border,
      onPrimary: Colors.white,
      onSurface: colors.textPrimary,
    );

    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textMuted,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: colors.textPrimary,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary, size: 22),
      ),

      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.borderSoft),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colors.borderSoft,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surface,
        contentTextStyle: TextStyle(color: colors.textPrimary),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _isDark ? colors.surfaceSoft : colors.surface,
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: colors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error, width: 1.4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size(double.infinity, 56),
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          textStyle: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colors.surfaceSoft,
        selectedColor: colors.primary.withValues(alpha: 0.12),
        disabledColor: colors.borderSoft,
        side: BorderSide(color: colors.border),
        labelStyle: TextStyle(color: colors.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colors.primary);
          }
          return IconThemeData(color: colors.textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.textMuted,
          );
        }),
      ),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: _isDark ? 0.22 : 0.08),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: _isDark ? 0.28 : 0.12),
      blurRadius: 40,
      offset: const Offset(0, 14),
    ),
  ];
}

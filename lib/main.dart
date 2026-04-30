import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'pages/splash_screen.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Set portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ✅ Initialize theme before running app
  await ThemeService.init();

  // ✅ Setup system UI
  _setupSystemUI(ThemeService.themeNotifier.value);

  runApp(const EmotionApp());
}

// ✅ Configure system UI based on theme
void _setupSystemUI(String themeName) {
  final isDark = themeName.toLowerCase() == 'dark';
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
}

class EmotionApp extends StatefulWidget {
  const EmotionApp({super.key});

  @override
  State<EmotionApp> createState() => _EmotionAppState();
}

class _EmotionAppState extends State<EmotionApp> {
  @override
  void initState() {
    super.initState();
    // ✅ Listen to theme changes
    ThemeService.themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeService.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  // ✅ Update UI when theme changes
  void _onThemeChanged() {
    _setupSystemUI(ThemeService.themeNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, themeName, child) {
        return MaterialApp(
          title: 'EMOTRA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,  // ✅ Dynamic theme from theme.dart
          home: const SplashScreen(),
        );
      },
    );
  }
}

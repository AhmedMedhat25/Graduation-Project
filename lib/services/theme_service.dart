import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// CHANGED: Added ThemeService to handle 4 themes and persistence
class ThemeService {
  static const String _themeKey = 'app_theme';

  // We use ValueNotifier<String> because ThemeMode only supports light/dark
  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>('Light');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey) ?? 'Light';
    themeNotifier.value = savedTheme;
  }

  static Future<void> setTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
    themeNotifier.value = themeName;
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  // Singleton pattern for easy access
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() {
    return instance;
  }

  ThemeController._internal() : super(ThemeMode.light) {
    _loadTheme();
  }

  static const String _key = 'is_dark_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? false;
    // Notify listeners only if needed, but since it's init, value setter handles it
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final isDark = value == ThemeMode.dark;
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, !isDark);
  }

  bool get isDarkMode => value == ThemeMode.dark;
}

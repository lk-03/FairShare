import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _modeKey = 'fairshare_theme_mode';

  @override
  ThemeMode build() {
    _loadFromPreferences();
    return ThemeMode.system;
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModeName = prefs.getString(_modeKey);

      if (savedModeName != null) {
        for (final m in ThemeMode.values) {
          if (m.name == savedModeName) {
            state = m;
            break;
          }
        }
      }
    } catch (_) {
      // Fallback gracefully to system mode
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } catch (_) {}
  }

  ThemeData get lightTheme => AppTheme.buildTheme(
        brightness: Brightness.light,
      );

  ThemeData get darkTheme => AppTheme.buildTheme(
        brightness: Brightness.dark,
      );
}

/// Global provider for application theme mode (Light, Dark, System)
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

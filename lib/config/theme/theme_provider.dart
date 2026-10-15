import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

enum AppThemeStyle {
  system,
  light,
  darkNordic,
  darkAmoled,
}

class ThemeStyleNotifier extends Notifier<AppThemeStyle> {
  static const _styleKey = 'fairshare_theme_style';

  @override
  AppThemeStyle build() {
    _loadFromPreferences();
    return AppThemeStyle.system;
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStyle = prefs.getString(_styleKey);

      if (savedStyle != null) {
        for (final s in AppThemeStyle.values) {
          if (s.name == savedStyle) {
            state = s;
            return;
          }
        }
      }

      // Legacy fallback
      final legacyMode = prefs.getString('fairshare_theme_mode');
      if (legacyMode == 'dark') {
        state = AppThemeStyle.darkNordic;
      } else if (legacyMode == 'light') {
        state = AppThemeStyle.light;
      }
    } catch (_) {}
  }

  Future<void> setStyle(AppThemeStyle style) async {
    state = style;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_styleKey, style.name);
    } catch (_) {}
  }
}

final themeStyleProvider =
    NotifierProvider<ThemeStyleNotifier, AppThemeStyle>(ThemeStyleNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final style = ref.watch(themeStyleProvider);
    switch (style) {
      case AppThemeStyle.system:
        return ThemeMode.system;
      case AppThemeStyle.light:
        return ThemeMode.light;
      case AppThemeStyle.darkNordic:
      case AppThemeStyle.darkAmoled:
        return ThemeMode.dark;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    final styleNotifier = ref.read(themeStyleProvider.notifier);
    switch (mode) {
      case ThemeMode.system:
        await styleNotifier.setStyle(AppThemeStyle.system);
        break;
      case ThemeMode.light:
        await styleNotifier.setStyle(AppThemeStyle.light);
        break;
      case ThemeMode.dark:
        await styleNotifier.setStyle(AppThemeStyle.darkNordic);
        break;
    }
  }

  ThemeData get lightTheme => AppTheme.buildTheme(
        brightness: Brightness.light,
      );

  ThemeData get darkTheme {
    final style = ref.watch(themeStyleProvider);
    return AppTheme.buildTheme(
      brightness: Brightness.dark,
      isAmoled: style == AppThemeStyle.darkAmoled,
    );
  }
}

/// Global provider for application theme mode (Light, Dark, System)
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);


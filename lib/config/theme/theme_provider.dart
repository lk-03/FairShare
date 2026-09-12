import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'theme_palettes.dart';

class ThemeState {
  final ThemePalette palette;
  final ThemeMode mode;

  const ThemeState({
    required this.palette,
    required this.mode,
  });

  ThemeState copyWith({
    ThemePalette? palette,
    ThemeMode? mode,
  }) {
    return ThemeState(
      palette: palette ?? this.palette,
      mode: mode ?? this.mode,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const _paletteKey = 'fairshare_theme_palette';
  static const _modeKey = 'fairshare_theme_mode';

  @override
  ThemeState build() {
    _loadFromPreferences();
    return const ThemeState(
      palette: ThemePalette.nordic,
      mode: ThemeMode.system,
    );
  }

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPaletteName = prefs.getString(_paletteKey);
      final savedModeName = prefs.getString(_modeKey);

      ThemePalette palette = ThemePalette.nordic;
      if (savedPaletteName != null) {
        for (final p in ThemePalette.values) {
          if (p.name == savedPaletteName) {
            palette = p;
            break;
          }
        }
      }

      ThemeMode mode = ThemeMode.system;
      if (savedModeName != null) {
        for (final m in ThemeMode.values) {
          if (m.name == savedModeName) {
            mode = m;
            break;
          }
        }
      }

      state = state.copyWith(palette: palette, mode: mode);
    } catch (_) {
      // Fallback gracefully to default state
    }
  }

  Future<void> setPalette(ThemePalette palette) async {
    state = state.copyWith(palette: palette);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_paletteKey, palette.name);
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
    } catch (_) {}
  }

  ThemeData get lightTheme => AppTheme.buildTheme(
        palette: state.palette,
        brightness: Brightness.light,
      );

  ThemeData get darkTheme => AppTheme.buildTheme(
        palette: state.palette,
        brightness: Brightness.dark,
      );
}

/// Global provider for application theme state
final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);

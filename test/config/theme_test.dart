import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_colors.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/config/theme/theme_palettes.dart';

void main() {
  group('Blue Theme & AppTheme', () {
    test('blue theme should have valid light and dark tokens', () {
      final dark = AppPalettes.getColors(Brightness.dark);
      final light = AppPalettes.getColors(Brightness.light);

      expect(dark.screen, const Color(0xFF0D131A));
      expect(dark.surface, const Color(0xFF121A23));
      expect(dark.cyan, const Color(0xFF38BDF8));
      expect(dark.gradStart, const Color(0xFF2B3E50));
      expect(dark.chartColors.length, 8);

      expect(light.screen, const Color(0xFFF8FAFC));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.cyan, const Color(0xFF0284C7));
      expect(light.gradStart, const Color(0xFFDCE7F0));
      expect(light.chartColors.length, 8);
    });

    test('AppTheme.buildTheme attaches AppThemeColors extension', () {
      final theme = AppTheme.buildTheme(
        brightness: Brightness.dark,
      );

      final extension = theme.extension<AppThemeColors>();
      expect(extension, isNotNull);
      expect(extension?.screen, AppPalettes.dark.screen);
      expect(extension?.cyan, AppPalettes.dark.cyan);
      expect(theme.scaffoldBackgroundColor, AppPalettes.dark.screen);
    });

    test('AppThemeColors copyWith and lerp', () {
      final base = AppPalettes.dark;
      final copied = base.copyWith(cyan: Colors.blue);
      expect(copied.cyan, Colors.blue);
      expect(copied.screen, base.screen);

      final lerped = base.lerp(AppPalettes.light, 0.5);
      expect(lerped, isNotNull);
      expect(lerped.screen, isNot(base.screen));
      expect(lerped.screen, isNot(AppPalettes.light.screen));
    });
  });
}

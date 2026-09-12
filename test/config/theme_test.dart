import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_colors.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/config/theme/theme_palettes.dart';

void main() {
  group('Theme Palettes & AppTheme', () {
    test('all 4 palettes should have valid light and dark tokens', () {
      for (final palette in ThemePalette.values) {
        final dark = AppPalettes.getColors(palette, Brightness.dark);
        final light = AppPalettes.getColors(palette, Brightness.light);

        expect(dark.screen, isNotNull);
        expect(dark.surface, isNotNull);
        expect(dark.border, isNotNull);
        expect(dark.textMain, isNotNull);
        expect(dark.textSecondary, isNotNull);
        expect(dark.cyan, isNotNull);
        expect(dark.red, isNotNull);
        expect(dark.emerald, isNotNull);
        expect(dark.gradStart, isNotNull);
        expect(dark.gradMid, isNotNull);
        expect(dark.gradEnd, isNotNull);
        expect(dark.chartColors.length, 8);

        expect(light.screen, isNotNull);
        expect(light.surface, isNotNull);
        expect(light.border, isNotNull);
        expect(light.textMain, isNotNull);
        expect(light.textSecondary, isNotNull);
        expect(light.cyan, isNotNull);
        expect(light.red, isNotNull);
        expect(light.emerald, isNotNull);
        expect(light.gradStart, isNotNull);
        expect(light.gradMid, isNotNull);
        expect(light.gradEnd, isNotNull);
        expect(light.chartColors.length, 8);
      }
    });

    test('AppTheme.buildTheme attaches AppThemeColors extension', () {
      final theme = AppTheme.buildTheme(
        palette: ThemePalette.nordic,
        brightness: Brightness.dark,
      );

      final extension = theme.extension<AppThemeColors>();
      expect(extension, isNotNull);
      expect(extension?.screen, AppPalettes.nordicDark.screen);
      expect(extension?.cyan, AppPalettes.nordicDark.cyan);
      expect(theme.scaffoldBackgroundColor, AppPalettes.nordicDark.screen);
    });

    test('AppThemeColors copyWith and lerp', () {
      final base = AppPalettes.nordicDark;
      final copied = base.copyWith(cyan: Colors.blue);
      expect(copied.cyan, Colors.blue);
      expect(copied.screen, base.screen);

      final lerped = base.lerp(AppPalettes.nordicLight, 0.5);
      expect(lerped, isNotNull);
      expect(lerped.screen, isNot(base.screen));
      expect(lerped.screen, isNot(AppPalettes.nordicLight.screen));
    });
  });
}

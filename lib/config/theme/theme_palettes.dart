import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Available theme palettes in FairShare
enum ThemePalette {
  nordic(
    name: 'Nordic Steel',
    subtitle: 'Understated Scandinavian Blue',
    previewColor: Color(0xFF2B3E50),
  ),
  sage(
    name: 'Muted Sage',
    subtitle: 'Organic Eucalyptus & Pine',
    previewColor: Color(0xFF33453E),
  ),
  taupe(
    name: 'Warm Taupe',
    subtitle: 'Cozy Sand & Mocha Clay',
    previewColor: Color(0xFF3D3534),
  ),
  cobalt(
    name: 'Electric Cobalt',
    subtitle: 'High-Tech Neo-Fintech Blue',
    previewColor: Color(0xFF2563EB),
  );

  final String name;
  final String subtitle;
  final Color previewColor;

  const ThemePalette({
    required this.name,
    required this.subtitle,
    required this.previewColor,
  });
}

/// AppPalettes provides complete 1:1 color definitions for all 4 palettes
/// in both Dark and Light variants, matching FairShare's design tokens.
class AppPalettes {
  static const List<Color> standardChartColors = [
    Color(0xFF38BDF8), // 1: Sky
    Color(0xFF34D399), // 2: Emerald
    Color(0xFFA78BFA), // 3: Violet
    Color(0xFFFB923C), // 4: Orange
    Color(0xFFF472B6), // 5: Rose
    Color(0xFFFBBF24), // 6: Amber
    Color(0xFF2DD4BF), // 7: Teal
    Color(0xFF818CF8), // 8: Indigo
  ];

  // ===========================================================================
  // 1. NORDIC STEEL (Default - Clean Scandinavian Steel Blue & Midnight Slate)
  // ===========================================================================
  static const AppThemeColors nordicDark = AppThemeColors(
    screen: Color(0xFF0D131A),
    surface: Color(0xFF121A23),
    surfaceElevated: Color(0xFF1B2735),
    border: Color(0xFF243447),
    borderSubtle: Color(0xFF1A2634),
    textMain: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF7E95A8),
    textMuted: Color(0xFF52667A),
    accentPill: Color(0x1FFFFFFF),
    accentPillText: Color(0xFFFFFFFF),
    cyan: Color(0xFF38BDF8),
    red: Color(0xFFF87171),
    emerald: Color(0xFF34D399),
    amber: Color(0xFFFBBF24),
    gradStart: Color(0xFF2B3E50),
    gradMid: Color(0xFF182533),
    gradEnd: Color(0xFF0D131A),
    chartColors: standardChartColors,
  );

  static const AppThemeColors nordicLight = AppThemeColors(
    screen: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderSubtle: Color(0xFFEDF2F7),
    textMain: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    accentPill: Color(0x0D000000),
    accentPillText: Color(0xFF1E293B),
    cyan: Color(0xFF0284C7),
    red: Color(0xFFE11D48),
    emerald: Color(0xFF059669),
    amber: Color(0xFFD97706),
    gradStart: Color(0xFFDCE7F0),
    gradMid: Color(0xFFEDF2F7),
    gradEnd: Color(0xFFF8FAFC),
    chartColors: standardChartColors,
  );

  // ===========================================================================
  // 2. MUTED SAGE (Organic Eucalyptus & Deep Pine Forest)
  // ===========================================================================
  static const AppThemeColors sageDark = AppThemeColors(
    screen: Color(0xFF0E1412),
    surface: Color(0xFF141C19),
    surfaceElevated: Color(0xFF1E2B26),
    border: Color(0xFF24332D),
    borderSubtle: Color(0xFF1A2621),
    textMain: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8BA398),
    textMuted: Color(0xFF5E7369),
    accentPill: Color(0x1FFFFFFF),
    accentPillText: Color(0xFFFFFFFF),
    cyan: Color(0xFF34D399),
    red: Color(0xFFF87171),
    emerald: Color(0xFF34D399),
    amber: Color(0xFFFBBF24),
    gradStart: Color(0xFF33453E),
    gradMid: Color(0xFF1E2B26),
    gradEnd: Color(0xFF0E1412),
    chartColors: standardChartColors,
  );

  static const AppThemeColors sageLight = AppThemeColors(
    screen: Color(0xFFF7FAF8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEFF4F1),
    border: Color(0xFFDCE6E0),
    borderSubtle: Color(0xFFE8EFEA),
    textMain: Color(0xFF14201A),
    textSecondary: Color(0xFF586B62),
    textMuted: Color(0xFF8A9C93),
    accentPill: Color(0x0D000000),
    accentPillText: Color(0xFF14201A),
    cyan: Color(0xFF059669),
    red: Color(0xFFE11D48),
    emerald: Color(0xFF059669),
    amber: Color(0xFFD97706),
    gradStart: Color(0xFFDFE8E2),
    gradMid: Color(0xFFEFF4F1),
    gradEnd: Color(0xFFF7FAF8),
    chartColors: standardChartColors,
  );

  // ===========================================================================
  // 3. WARM TAUPE (Cozy Sand & Mocha Clay)
  // ===========================================================================
  static const AppThemeColors taupeDark = AppThemeColors(
    screen: Color(0xFF110E0E),
    surface: Color(0xFF181414),
    surfaceElevated: Color(0xFF241E1E),
    border: Color(0xFF2E2626),
    borderSubtle: Color(0xFF211A1A),
    textMain: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFC4B5A5),
    textMuted: Color(0xFF8A7C6E),
    accentPill: Color(0x1FFFFFFF),
    accentPillText: Color(0xFFFFFFFF),
    cyan: Color(0xFFF59E0B),
    red: Color(0xFFF87171),
    emerald: Color(0xFF34D399),
    amber: Color(0xFFFBBF24),
    gradStart: Color(0xFF3D3534),
    gradMid: Color(0xFF241E1E),
    gradEnd: Color(0xFF110E0E),
    chartColors: standardChartColors,
  );

  static const AppThemeColors taupeLight = AppThemeColors(
    screen: Color(0xFFFAF8F6),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF6F3F0),
    border: Color(0xFFEBE4DC),
    borderSubtle: Color(0xFFF0EBE5),
    textMain: Color(0xFF1C1717),
    textSecondary: Color(0xFF7A6A5F),
    textMuted: Color(0xFFA19186),
    accentPill: Color(0x0D000000),
    accentPillText: Color(0xFF201A1A),
    cyan: Color(0xFFD97706),
    red: Color(0xFFE11D48),
    emerald: Color(0xFF059669),
    amber: Color(0xFFB45309),
    gradStart: Color(0xFFEBE5DF),
    gradMid: Color(0xFFF6F3F0),
    gradEnd: Color(0xFFFAF8F6),
    chartColors: standardChartColors,
  );

  // ===========================================================================
  // 4. ELECTRIC COBALT (High-Tech Royal Blue & Midnight Fintech)
  // ===========================================================================
  static const AppThemeColors cobaltDark = AppThemeColors(
    screen: Color(0xFF080C14),
    surface: Color(0xFF0F172A),
    surfaceElevated: Color(0xFF1E293B),
    border: Color(0xFF1E293B),
    borderSubtle: Color(0xFF162035),
    textMain: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    accentPill: Color(0x26FFFFFF),
    accentPillText: Color(0xFFFFFFFF),
    cyan: Color(0xFF38BDF8),
    red: Color(0xFFF87171),
    emerald: Color(0xFF34D399),
    amber: Color(0xFFFBBF24),
    gradStart: Color(0xFF2563EB),
    gradMid: Color(0xFF1D4ED8),
    gradEnd: Color(0xFF080C14),
    chartColors: standardChartColors,
  );

  static const AppThemeColors cobaltLight = AppThemeColors(
    screen: Color(0xFFF8FAFF),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFEFF6FF),
    border: Color(0xFFDBEAFE),
    borderSubtle: Color(0xFFE6F0FD),
    textMain: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    accentPill: Color(0x142563EB),
    accentPillText: Color(0xFF1D4ED8),
    cyan: Color(0xFF2563EB),
    red: Color(0xFFE11D48),
    emerald: Color(0xFF059669),
    amber: Color(0xFFD97706),
    gradStart: Color(0xFFDBEAFE),
    gradMid: Color(0xFFEFF6FF),
    gradEnd: Color(0xFFF8FAFF),
    chartColors: standardChartColors,
  );

  /// Resolves the concrete [AppThemeColors] for a given palette and brightness.
  static AppThemeColors getColors(ThemePalette palette, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (palette) {
      case ThemePalette.nordic:
        return isDark ? nordicDark : nordicLight;
      case ThemePalette.sage:
        return isDark ? sageDark : sageLight;
      case ThemePalette.taupe:
        return isDark ? taupeDark : taupeLight;
      case ThemePalette.cobalt:
        return isDark ? cobaltDark : cobaltLight;
    }
  }
}

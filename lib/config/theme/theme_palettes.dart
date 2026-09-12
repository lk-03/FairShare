import 'package:flutter/material.dart';
import 'app_colors.dart';

/// AppPalettes provides the unified, signature Electric Cobalt / Royal Blue
/// neo-fintech design tokens for FairShare in both Dark and Light variants.
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
  // FAIRSHARE NORDIC BLUE: DARK MODE (Nordic Steel & Midnight Charcoal)
  // ===========================================================================
  static const AppThemeColors dark = AppThemeColors(
    screen: Color(0xFF0D131A),
    surface: Color(0xFF121A23),
    surfaceElevated: Color(0xFF1C2735),
    border: Color(0xFF243447),
    borderSubtle: Color(0xFF182432),
    textMain: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF7E95A8),
    textMuted: Color(0xFF556877),
    accentPill: Color(0x1AFFFFFF),
    accentPillText: Color(0xFFFFFFFF),
    cyan: Color(0xFF38BDF8), // Subtle Nordic sky cyan accent
    red: Color(0xFFF87171),
    emerald: Color(0xFF34D399),
    amber: Color(0xFFFBBF24),
    gradStart: Color(0xFF2B3E50), // Scandinavian Steel Blue
    gradMid: Color(0xFF182533), // Deep Navy Slate
    gradEnd: Color(0xFF0D131A), // Charcoal Screen Blend
    chartColors: standardChartColors,
  );

  // ===========================================================================
  // FAIRSHARE NORDIC BLUE: LIGHT MODE (Crisp Ice Slate & Pure White Surface)
  // ===========================================================================
  static const AppThemeColors light = AppThemeColors(
    screen: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    borderSubtle: Color(0xFFEEF2F6),
    textMain: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    accentPill: Color(0x0D000000),
    accentPillText: Color(0xFF0284C7),
    cyan: Color(0xFF0284C7), // Subtle Nordic Ocean Blue
    red: Color(0xFFE11D48),
    emerald: Color(0xFF059669),
    amber: Color(0xFFD97706),
    gradStart: Color(0xFFDCE7F0), // Soft Ice Slate
    gradMid: Color(0xFFEDF2F7), // Neutral Slate
    gradEnd: Color(0xFFF8FAFC), // Crisp Off-White
    chartColors: standardChartColors,
  );

  /// Resolves the concrete [AppThemeColors] for a given brightness.
  static AppThemeColors getColors(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

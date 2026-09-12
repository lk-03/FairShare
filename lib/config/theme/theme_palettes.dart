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
  // FAIRSHARE SIGNATURE BLUE: DARK MODE (Electric Cobalt & Midnight Fintech)
  // ===========================================================================
  static const AppThemeColors dark = AppThemeColors(
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
    cyan: Color(0xFF38BDF8), // Electric sky cyan accent
    red: Color(0xFFF87171),
    emerald: Color(0xFF34D399),
    amber: Color(0xFFFBBF24),
    gradStart: Color(0xFF2563EB), // Royal Blue
    gradMid: Color(0xFF1D4ED8), // Deep Blue
    gradEnd: Color(0xFF080C14), // Screen background blend
    chartColors: standardChartColors,
  );

  // ===========================================================================
  // FAIRSHARE SIGNATURE BLUE: LIGHT MODE (Crisp Ice Blue & Soft Azure Surface)
  // ===========================================================================
  static const AppThemeColors light = AppThemeColors(
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

  /// Resolves the concrete [AppThemeColors] for a given brightness.
  static AppThemeColors getColors(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

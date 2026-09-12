import 'package:flutter/material.dart';

/// AppThemeColors defines the granular, strongly-typed design token set for FairShare,
/// matching the Revolut-inspired neo-fintech visual system.
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color screen;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderSubtle;
  final Color textMain;
  final Color textSecondary;
  final Color textMuted;
  final Color accentPill;
  final Color accentPillText;
  final Color cyan;
  final Color red;
  final Color emerald;
  final Color amber;
  final Color gradStart;
  final Color gradMid;
  final Color gradEnd;
  final List<Color> chartColors;

  const AppThemeColors({
    required this.screen,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderSubtle,
    required this.textMain,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPill,
    required this.accentPillText,
    required this.cyan,
    required this.red,
    required this.emerald,
    required this.amber,
    required this.gradStart,
    required this.gradMid,
    required this.gradEnd,
    required this.chartColors,
  });

  Color get textPositive => emerald;
  Color get textNegative => red;

  @override
  AppThemeColors copyWith({
    Color? screen,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? borderSubtle,
    Color? textMain,
    Color? textSecondary,
    Color? textMuted,
    Color? accentPill,
    Color? accentPillText,
    Color? cyan,
    Color? red,
    Color? emerald,
    Color? amber,
    Color? gradStart,
    Color? gradMid,
    Color? gradEnd,
    List<Color>? chartColors,
  }) {
    return AppThemeColors(
      screen: screen ?? this.screen,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textMain: textMain ?? this.textMain,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentPill: accentPill ?? this.accentPill,
      accentPillText: accentPillText ?? this.accentPillText,
      cyan: cyan ?? this.cyan,
      red: red ?? this.red,
      emerald: emerald ?? this.emerald,
      amber: amber ?? this.amber,
      gradStart: gradStart ?? this.gradStart,
      gradMid: gradMid ?? this.gradMid,
      gradEnd: gradEnd ?? this.gradEnd,
      chartColors: chartColors ?? this.chartColors,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      screen: Color.lerp(screen, other.screen, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      textMain: Color.lerp(textMain, other.textMain, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentPill: Color.lerp(accentPill, other.accentPill, t)!,
      accentPillText: Color.lerp(accentPillText, other.accentPillText, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      red: Color.lerp(red, other.red, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      gradStart: Color.lerp(gradStart, other.gradStart, t)!,
      gradMid: Color.lerp(gradMid, other.gradMid, t)!,
      gradEnd: Color.lerp(gradEnd, other.gradEnd, t)!,
      chartColors: other.chartColors,
    );
  }
}

/// Convenience extension on [BuildContext] for ergonomic access to [AppThemeColors].
extension ThemeContextExtension on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ??
      const AppThemeColors(
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
        cyan: Color(0xFF38BDF8),
        red: Color(0xFFF87171),
        emerald: Color(0xFF34D399),
        amber: Color(0xFFFBBF24),
        gradStart: Color(0xFF2B3E50),
        gradMid: Color(0xFF182533),
        gradEnd: Color(0xFF0D131A),
        chartColors: [
          Color(0xFF38BDF8),
          Color(0xFF34D399),
          Color(0xFFA78BFA),
          Color(0xFFFB923C),
          Color(0xFFF472B6),
          Color(0xFFFBBF24),
          Color(0xFF2DD4BF),
          Color(0xFF818CF8),
        ],
      );
}

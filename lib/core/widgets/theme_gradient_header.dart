import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

/// ThemeGradientHeader renders the signature Revolut-style multi-stop gradient header
/// with curved bottom corners and safe-area insets.
class ThemeGradientHeader extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<Color>? customColors;

  const ThemeGradientHeader({
    super.key,
    required this.child,
    this.borderRadius = 36.0,
    this.padding,
    this.customColors,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.of(context).padding.top;

    final gradientColors = customColors ??
        [
          colors.gradStart,
          colors.gradMid,
          colors.gradEnd,
        ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(borderRadius),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45, 1.0],
          colors: gradientColors,
        ),
      ),
      padding: EdgeInsets.only(
        top: topInset + (padding?.resolve(Directionality.of(context)).top ?? 12.0),
        bottom: padding?.resolve(Directionality.of(context)).bottom ?? 24.0,
        left: padding?.resolve(Directionality.of(context)).left ?? 20.0,
        right: padding?.resolve(Directionality.of(context)).right ?? 20.0,
      ),
      child: child,
    );
  }
}

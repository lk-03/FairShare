import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

/// AppLogo displays the official FairShare symbol mark with configurable
/// size, tint color, ambient glow, and drop shadow.
class AppLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool withGlow;
  final bool withShadow;

  const AppLogo({
    super.key,
    this.size = 32,
    this.color,
    this.withGlow = false,
    this.withShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = color ?? context.colors.cyan;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (withGlow)
            Container(
              width: size * 1.25,
              height: size * 1.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
              ),
            ),
          Container(
            width: size,
            height: size,
            decoration: withShadow
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        offset: const Offset(0, 3),
                        blurRadius: 6,
                      ),
                    ],
                  )
                : null,
            child: Image.asset(
              'assets/images/logo-symbol.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              color: color,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.account_balance_wallet_rounded,
                  size: size * 0.85,
                  color: accentColor,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

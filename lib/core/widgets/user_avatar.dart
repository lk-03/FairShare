import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import 'avatar_picker_modal.dart';

/// UserAvatar renders a user profile picture or character avatar.
/// If no avatarUrl is set, it computes a deterministic illustrated character
/// avatar using DiceBear based on the user's name or ID.
class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String? name;
  final String? userId;
  final double radius;
  final double borderWidth;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    this.name,
    this.userId,
    this.radius = 20,
    this.borderWidth = 0,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  String _getDeterministicAvatarUrl() {
    final seed = (userId != null && userId!.trim().isNotEmpty)
        ? userId!.trim()
        : (name != null && name!.trim().isNotEmpty)
            ? name!.trim()
            : 'FairShare';

    final hash = seed.hashCode.abs();
    return diverseCartoonAvatars[hash % diverseCartoonAvatars.length];
  }

  String _getEffectiveUrl() {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return avatarUrl!.trim();
    }
    return _getDeterministicAvatarUrl();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = radius * 2;
    final url = _getEffectiveUrl();
    final initial = (name != null && name!.trim().isNotEmpty)
        ? name!.trim()[0].toUpperCase()
        : '?';

    Widget avatarContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? colors.accentPill,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? colors.border,
                width: borderWidth,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w700,
                color: colors.cyan,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: colors.accentPill,
            child: Center(
              child: SizedBox(
                width: size * 0.35,
                height: size * 0.35,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colors.cyan.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarContent,
      );
    }

    return avatarContent;
  }
}

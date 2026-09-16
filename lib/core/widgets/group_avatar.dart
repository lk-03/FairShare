import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';
import 'category_icon.dart';

class GroupAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String category;
  final String? customIcon;
  final double size;
  final CategoryIconVariant variant;

  const GroupAvatar({
    super.key,
    this.avatarUrl,
    required this.category,
    this.customIcon,
    this.size = 48.0,
    this.variant = CategoryIconVariant.solid,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          color: const Color(0xFF1E293B),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CategoryIcon(
            category: category,
            customIcon: customIcon,
            size: size,
            variant: variant,
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: colors.accentPill,
              child: Center(
                child: SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return CategoryIcon(
      category: category,
      customIcon: customIcon,
      size: size,
      variant: variant,
    );
  }
}

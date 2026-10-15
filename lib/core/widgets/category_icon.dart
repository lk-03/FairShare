import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

enum CategoryIconVariant { solid, light }

class CategoryStyleConfig {
  final IconData iconData;
  final String label;
  final Color darkBg;
  final Color darkBorder;
  final Color darkIcon;
  final Color lightBg;
  final Color lightBorder;
  final Color lightIcon;

  const CategoryStyleConfig({
    required this.iconData,
    required this.label,
    required this.darkBg,
    required this.darkBorder,
    required this.darkIcon,
    required this.lightBg,
    required this.lightBorder,
    required this.lightIcon,
  });
}

const Map<String, CategoryStyleConfig> categoryStyles = {
  'trip': CategoryStyleConfig(
    iconData: Icons.flight_rounded,
    label: 'Trip',
    darkBg: Color(0xFF1E293B),
    darkBorder: Color(0xFF334155),
    darkIcon: Color(0xFF38BDF8),
    lightBg: Color(0xFFE0F2FE),
    lightBorder: Color(0xFFBAE6FD),
    lightIcon: Color(0xFF0284C7),
  ),
  'house': CategoryStyleConfig(
    iconData: Icons.home_rounded,
    label: 'House',
    darkBg: Color(0xFF1E2B26),
    darkBorder: Color(0xFF2D3F36),
    darkIcon: Color(0xFF34D399),
    lightBg: Color(0xFFDCFCE7),
    lightBorder: Color(0xFFBBF7D0),
    lightIcon: Color(0xFF16A34A),
  ),
  'dining': CategoryStyleConfig(
    iconData: Icons.restaurant_rounded,
    label: 'Dining',
    darkBg: Color(0xFF2E241E),
    darkBorder: Color(0xFF42342A),
    darkIcon: Color(0xFFFBBF24),
    lightBg: Color(0xFFFEF3C7),
    lightBorder: Color(0xFFFDE68A),
    lightIcon: Color(0xFFD97706),
  ),
  'event': CategoryStyleConfig(
    iconData: Icons.event_rounded,
    label: 'Event',
    darkBg: Color(0xFF2E1E28),
    darkBorder: Color(0xFF422A39),
    darkIcon: Color(0xFFF472B6),
    lightBg: Color(0xFFFCE7F3),
    lightBorder: Color(0xFFFBCFE8),
    lightIcon: Color(0xFFDB2777),
  ),
  'transport': CategoryStyleConfig(
    iconData: Icons.directions_car_rounded,
    label: 'Transport',
    darkBg: Color(0xFF1E293B),
    darkBorder: Color(0xFF334155),
    darkIcon: Color(0xFF94A3B8),
    lightBg: Color(0xFFF1F5F9),
    lightBorder: Color(0xFFCBD5E1),
    lightIcon: Color(0xFF475569),
  ),
  'utilities': CategoryStyleConfig(
    iconData: Icons.bolt_rounded,
    label: 'Utilities',
    darkBg: Color(0xFF251E38),
    darkBorder: Color(0xFF362B4E),
    darkIcon: Color(0xFFA78BFA),
    lightBg: Color(0xFFEDE9FE),
    lightBorder: Color(0xFFDDD6FE),
    lightIcon: Color(0xFF7C3AED),
  ),
  'settlement': CategoryStyleConfig(
    iconData: Icons.payments_rounded,
    label: 'Settlement',
    darkBg: Color(0xFF1E3A2B),
    darkBorder: Color(0xFF284E3A),
    darkIcon: Color(0xFF34D399),
    lightBg: Color(0xFFD1FAE5),
    lightBorder: Color(0xFFA7F3D0),
    lightIcon: Color(0xFF059669),
  ),
};

IconData mapCustomIconNameToIconData(String? name) {
  if (name == null || name.isEmpty) return Icons.category_rounded;
  switch (name.toLowerCase()) {
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'cart':
    case 'shopping':
      return Icons.shopping_cart_rounded;
    case 'fast-food':
    case 'fastfood':
    case 'snacks':
      return Icons.fastfood_rounded;
    case 'beer':
    case 'party':
      return Icons.sports_bar_rounded;
    case 'cafe':
    case 'coffee':
      return Icons.local_cafe_rounded;
    case 'briefcase':
    case 'work':
      return Icons.work_rounded;
    case 'laptop':
    case 'tech':
      return Icons.laptop_mac_rounded;
    case 'game-controller':
    case 'gaming':
      return Icons.sports_esports_rounded;
    case 'fitness':
    case 'gym':
      return Icons.fitness_center_rounded;
    case 'football':
    case 'sports':
      return Icons.sports_soccer_rounded;
    case 'film':
    case 'movie':
      return Icons.movie_rounded;
    case 'musical-notes':
    case 'music':
      return Icons.music_note_rounded;
    case 'camera':
    case 'photos':
      return Icons.camera_alt_rounded;
    case 'headset':
    case 'audio':
      return Icons.headphones_rounded;
    case 'medkit':
    case 'health':
      return Icons.medical_services_rounded;
    case 'build':
    case 'tools':
      return Icons.build_rounded;
    case 'construct':
    case 'repair':
      return Icons.handyman_rounded;
    case 'paw':
    case 'pets':
      return Icons.pets_rounded;
    case 'cash':
      return Icons.attach_money_rounded;
    case 'school':
    case 'study':
      return Icons.school_rounded;
    case 'book':
    case 'books':
      return Icons.menu_book_rounded;
    case 'bus':
    case 'transit':
      return Icons.directions_bus_rounded;
    case 'airplane':
    case 'flight':
      return Icons.flight_rounded;
    case 'car-sport':
    case 'drive':
      return Icons.directions_car_rounded;
    case 'heart':
    case 'love':
      return Icons.favorite_rounded;
    case 'shirt':
    case 'clothes':
      return Icons.checkroom_rounded;
    case 'flame':
    case 'hot':
      return Icons.local_fire_department_rounded;
    case 'sparkles':
    case 'vip':
      return Icons.auto_awesome_rounded;
    case 'key':
    case 'rent':
      return Icons.key_rounded;
    case 'diamond':
    case 'luxe':
      return Icons.diamond_rounded;
    default:
      return Icons.category_rounded;
  }
}

class CategoryIcon extends StatelessWidget {
  final String category;
  final String? customIcon;
  final double size;
  final Color? color;
  final CategoryIconVariant variant;

  const CategoryIcon({
    super.key,
    required this.category,
    this.customIcon,
    this.size = 48.0,
    this.color,
    this.variant = CategoryIconVariant.solid,
  });

  const CategoryIcon.withVariant({
    super.key,
    required this.category,
    this.customIcon,
    this.size = 48.0,
    this.color,
    bool isSolid = true,
  }) : variant = isSolid ? CategoryIconVariant.solid : CategoryIconVariant.light;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cat = category.toLowerCase();
    final cfg = categoryStyles[cat];

    IconData iconData = Icons.category_rounded;
    Color bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    Color borderColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    Color iconColor = colors.cyan;

    if (cfg != null) {
      iconData = cfg.iconData;
      bgColor = isDark ? cfg.darkBg : cfg.lightBg;
      borderColor = isDark ? cfg.darkBorder : cfg.lightBorder;
      iconColor = isDark ? cfg.darkIcon : cfg.lightIcon;
    } else if (customIcon != null && customIcon!.isNotEmpty) {
      iconData = mapCustomIconNameToIconData(customIcon);
    }

    final double iconSize = (size * 0.50).roundToDouble();

    if (variant == CategoryIconVariant.light) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? const Color(0x2694A3B8) // rgba(148, 163, 184, 0.15)
              : const Color(0x1464748B), // rgba(100, 116, 139, 0.08)
          border: Border.all(
            color: isDark
                ? const Color(0x4094A3B8)
                : const Color(0x2664748B),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            iconData,
            size: iconSize,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color ?? bgColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}

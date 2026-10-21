import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/theme_provider.dart';
import '../../data/providers/auth_provider.dart';
import 'app_logo.dart';
import 'user_avatar.dart';

class FairShareDesktopSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FairShareDesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final themeNotifier = ref.watch(themeModeProvider.notifier);
    final currentThemeMode = ref.watch(themeModeProvider);

    final navItems = [
      _DesktopNavItem(
        label: 'Home',
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
      ),
      _DesktopNavItem(
        label: 'Groups',
        activeIcon: Icons.people_rounded,
        inactiveIcon: Icons.people_outline_rounded,
      ),
      _DesktopNavItem(
        label: 'Activity',
        activeIcon: Icons.access_time_filled_rounded,
        inactiveIcon: Icons.access_time_rounded,
      ),
      _DesktopNavItem(
        label: 'Profile',
        activeIcon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
      ),
    ];

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                const AppLogo(size: 32, withGlow: true, withShadow: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FairShare',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: colors.textMain,
                        ),
                      ),
                      Text(
                        'CLOUD LEDGER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: colors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 16),

          // Nav Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'NAVIGATION',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: navItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = currentIndex == index;

                return InkWell(
                  onTap: () => onTabSelected(index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.cyan.withValues(alpha: isDark ? 0.16 : 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: isSelected
                          ? Border.all(
                              color: colors.cyan.withValues(alpha: 0.35),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.inactiveIcon,
                          size: 20,
                          color: isSelected ? colors.cyan : colors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected
                                  ? colors.textMain
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.cyan,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // User Footer Profile & Theme Switcher
          Padding(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              onTap: () => onTabSelected(3), // Navigate to Profile tab
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: currentIndex == 3
                      ? colors.cyan.withValues(alpha: 0.1)
                      : colors.accentPill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: currentIndex == 3
                        ? colors.cyan.withValues(alpha: 0.3)
                        : colors.border,
                  ),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      avatarUrl: user?.avatarUrl,
                      name: user?.displayName,
                      userId: user?.id,
                      radius: 17,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user?.displayName.isNotEmpty == true
                                ? user!.displayName
                                : 'You',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textMain,
                            ),
                          ),
                          Text(
                            user?.email != null && user!.email!.isNotEmpty
                                ? user.email!
                                : (user?.username != null
                                    ? '@${user!.username}'
                                    : 'Account'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isDark ? 'Light Theme' : 'Dark Theme',
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 18,
                        color: colors.textSecondary,
                      ),
                      onPressed: () {
                        final next = currentThemeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                        themeNotifier.setMode(next);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopNavItem {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _DesktopNavItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme/app_colors.dart';

class FairShareBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const FairShareBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final tabs = [
      _NavTabItem(
        label: 'Home',
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
      ),
      _NavTabItem(
        label: 'Groups',
        activeIcon: Icons.people_rounded,
        inactiveIcon: Icons.people_outline_rounded,
      ),
      _NavTabItem(
        label: 'Activity',
        activeIcon: Icons.access_time_filled_rounded,
        inactiveIcon: Icons.access_time_rounded,
      ),
      _NavTabItem(
        label: 'Profile',
        activeIcon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline_rounded,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: bottomInset > 0 ? bottomInset : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = currentIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  HapticFeedback.selectionClick();
                  onTabSelected(index);
                }
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? tab.activeIcon : tab.inactiveIcon,
                      size: 24,
                      color: isSelected ? colors.cyan : colors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colors.textMain : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavTabItem {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _NavTabItem({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

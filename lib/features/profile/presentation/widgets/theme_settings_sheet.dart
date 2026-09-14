import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/theme_provider.dart';

class ThemeSettingsSheet extends ConsumerWidget {
  const ThemeSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ThemeSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentMode = ref.watch(themeModeProvider);

    final modes = [
      (
        mode: ThemeMode.system,
        label: 'System',
        icon: Icons.brightness_auto_rounded,
        subtitle: 'Match device system settings',
      ),
      (
        mode: ThemeMode.light,
        label: 'Light',
        icon: Icons.light_mode_rounded,
        subtitle: 'Clean high-contrast daytime look',
      ),
      (
        mode: ThemeMode.dark,
        label: 'Dark',
        icon: Icons.dark_mode_rounded,
        subtitle: 'Deep OLED Nordic night aesthetic',
      ),
    ];

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme & Appearance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Customize your visual aesthetic',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Mode Selector
            Text(
              'APPEARANCE MODE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            Column(
              children: modes.map((item) {
                final isSelected = currentMode == item.mode;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      ref.read(themeModeProvider.notifier).setMode(item.mode);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.accentPill : colors.screen,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? colors.cyan : colors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colors.cyan.withValues(alpha: 0.2)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? colors.cyan
                                  : colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: colors.textMain,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: colors.cyan,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Color Palette Card
            Text(
              'ACTIVE DESIGN SYSTEM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.screen,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.cyan,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.palette_rounded,
                      color: Color(0xFF0F172A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Nordic Steel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.textMain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.cyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: colors.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Understated Scandinavian minimalism with high-contrast Nordic blue',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

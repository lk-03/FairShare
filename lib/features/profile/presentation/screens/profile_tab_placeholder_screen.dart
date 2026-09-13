import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/theme_provider.dart';
import '../../../../core/widgets/theme_gradient_header.dart';
import '../../../../data/providers/auth_provider.dart';

class ProfileTabPlaceholderScreen extends ConsumerWidget {
  const ProfileTabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    String displayName = 'FairShare Member';
    if (user != null) {
      if (user.fullName.isNotEmpty) {
        displayName = user.fullName;
      } else if (user.nickname != null && user.nickname!.isNotEmpty) {
        displayName = user.nickname!;
      }
    }

    return Scaffold(
      backgroundColor: colors.screen,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ThemeGradientHeader(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: colors.textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Account, Theme & Cloud Sync',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.help_outline_rounded, color: colors.textMain),
                    tooltip: 'Replay App Tour',
                    onPressed: () => context.push('/welcome?mode=tour'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Profile Summary Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.cyan, width: 2),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: user?.avatarUrl != null &&
                                  user!.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  user.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: colors.accentPill,
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: colors.cyan,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: colors.accentPill,
                                  child: Icon(
                                    Icons.person_rounded,
                                    color: colors.cyan,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textMain,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? 'Offline Session',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (user?.vpaId != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user!.vpaId!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colors.cyan,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'SYNCED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: colors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Theme Appearance Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: colors.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'APPEARANCE (NORDIC STEEL)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: colors.cyan,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 16),
                              label: Text('Auto'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 16),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 16),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (set) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setMode(set.first);
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colors.cyan.withValues(alpha: 0.2);
                              }
                              return colors.accentPill;
                            }),
                            foregroundColor:
                                WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return colors.cyan;
                              }
                              return colors.textSecondary;
                            }),
                            side: WidgetStateProperty.all(
                              BorderSide(color: colors.border, width: 1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sign Out Button
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(currentUserProvider.notifier).signOut();
                      if (context.mounted) {
                        context.go('/welcome');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: colors.red.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(Icons.logout_rounded, size: 18, color: colors.red),
                    label: Text(
                      'Sign Out of FairShare',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.red,
                      ),
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

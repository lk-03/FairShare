import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/avatar_picker_modal.dart';
import '../../../../core/widgets/theme_gradient_header.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/repositories/profile_repository.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/set_upi_sheet.dart';
import '../widgets/splitwise_import_sheet.dart';
import '../widgets/theme_settings_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
        title: Text(
          'Log Out',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colors.textMain,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of FairShare?',
          style: TextStyle(
            fontSize: 14,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(currentUserProvider.notifier).signOut();
              await ref.read(onboardingProvider.notifier).resetOnboarding();
              if (context.mounted) {
                try {
                  context.go('/welcome');
                } catch (_) {
                  // Handled safely in unit test environments without GoRouter
                }
              }
            },
            child: Text(
              'Log Out',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider) ?? defaultGuestUser;

    final displayName = user.displayName.isNotEmpty ? user.displayName : 'You';
    final hasVpa = user.vpaId != null && user.vpaId!.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.screen,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Screen Header with Gradient
            ThemeGradientHeader(
              child: Column(
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
                    'Account, Preferences & Settlement Config',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Profile Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: colors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar with Camera Overlay
                        GestureDetector(
                          onTap: () {
                            AvatarPickerModal.show(
                              context,
                              currentAvatarUrl: user.avatarUrl,
                              onSelectAvatar: (newUrl) {
                                ref
                                    .read(currentUserProvider.notifier)
                                    .updateProfile(avatarUrl: newUrl);
                              },
                            );
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.cyan,
                                    width: 2.5,
                                  ),
                                  color: colors.accentPill,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: user.avatarUrl != null &&
                                        user.avatarUrl!.isNotEmpty
                                    ? Image.network(
                                        user.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Center(
                                          child: Text(
                                            displayName.isNotEmpty
                                                ? displayName[0].toUpperCase()
                                                : 'U',
                                            style: TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w900,
                                              color: colors.cyan,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          displayName.isNotEmpty
                                              ? displayName[0].toUpperCase()
                                              : 'U',
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w900,
                                            color: colors.cyan,
                                          ),
                                        ),
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: colors.cyan,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.surface,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Name & Verified Badge
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textMain,
                                  letterSpacing: -0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasVpa) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 20,
                                color: colors.cyan,
                              ),
                            ],
                          ],
                        ),

                        if (hasVpa) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.cyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Verified UPI',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: colors.cyan,
                              ),
                            ),
                          ),
                        ],

                        if (user.username != null &&
                            user.username!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${user.username}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],

                        if (user.email != null && user.email!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            user.email!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Edit Profile Button
                        OutlinedButton.icon(
                          onPressed: () {
                            EditProfileSheet.show(context, user: user);
                          },
                          icon: Icon(Icons.edit_outlined,
                              size: 15, color: colors.cyan),
                          label: Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.cyan,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            side: BorderSide(color: colors.border, width: 1),
                            backgroundColor: colors.accentPill,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options List
                  Column(
                    children: [
                      // Payment Methods (UPI)
                      _buildOptionTile(
                        context: context,
                        icon: Icons.credit_card_rounded,
                        iconBg: colors.accentPill,
                        iconColor: colors.cyan,
                        title: 'Payment Methods (UPI)',
                        subtitle: hasVpa
                            ? user.vpaId!
                            : 'Add UPI ID for 1-tap settlements',
                        onTap: () {
                          SetUpiSheet.show(context, user: user);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Import Splitwise CSV
                      _buildOptionTile(
                        context: context,
                        icon: Icons.swap_horiz_rounded,
                        iconBg: colors.emerald.withValues(alpha: 0.15),
                        iconColor: colors.emerald,
                        title: 'Import Splitwise CSV',
                        subtitle: 'Migrate full group history and expenses',
                        onTap: () {
                          SplitwiseImportSheet.show(context);
                        },
                      ),
                      const SizedBox(height: 10),

                      // Guide & Interactive Tour
                      _buildOptionTile(
                        context: context,
                        icon: Icons.explore_outlined,
                        iconBg: colors.accentPill,
                        iconColor: colors.cyan,
                        title: 'Guide & Interactive Tour',
                        subtitle:
                            'Learn about debt simplification and split modes',
                        onTap: () {
                          context.push('/welcome?mode=tour');
                        },
                      ),
                      const SizedBox(height: 10),

                      // Theme & Appearance
                      _buildOptionTile(
                        context: context,
                        icon: Icons.palette_outlined,
                        iconBg: colors.accentPill,
                        iconColor: colors.cyan,
                        title: 'Theme & Appearance',
                        subtitle: 'Custom color schemes & palettes',
                        onTap: () {
                          ThemeSettingsSheet.show(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Log Out Button
                  InkWell(
                    onTap: () => _showLogoutDialog(context, ref),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Branded Footer
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const AppLogo(
                            size: 22,
                            withShadow: true,
                            withGlow: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'FairShare',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: colors.textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version 1.0.0 (Build Ready)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

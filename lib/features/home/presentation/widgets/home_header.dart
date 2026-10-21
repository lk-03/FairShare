import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/theme_gradient_header.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';

class HomeHeader extends ConsumerWidget {
  final VoidCallback onAddExpense;
  final VoidCallback onScanReceipt;
  final VoidCallback onJoinGroup;
  final VoidCallback onCreateGroup;

  const HomeHeader({
    super.key,
    required this.onAddExpense,
    required this.onScanReceipt,
    required this.onJoinGroup,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);
    final netBalance = ref.watch(overallNetBalanceProvider);
    final netTotal = netBalance.netTotal;

    String formattedTotal;
    if (netTotal > 0.01) {
      formattedTotal = '+₹${netTotal.toStringAsFixed(2)}';
    } else if (netTotal < -0.01) {
      formattedTotal = '-₹${netTotal.abs().toStringAsFixed(2)}';
    } else {
      formattedTotal = '₹0.00';
    }

    final Color statusDotColor = netTotal > 0.01
        ? colors.emerald
        : netTotal < -0.01
            ? colors.red
            : const Color(0xFF94A3B8);

    final String statusText = netTotal > 0.01
        ? 'Total amount you are owed'
        : netTotal < -0.01
            ? 'Total amount you owe'
            : 'You are all settled up';

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return ThemeGradientHeader(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: on desktop, show sleek greeting without duplicate logo/avatar
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${user?.displayName ?? 'Friend'}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Financial overview across all your shared groups',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.accentPill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.emerald,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cloud Sync Active',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            // Mobile Top bar: AppLogo, App Name & Profile Avatar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppLogo(size: 32, withShadow: false, withGlow: false),
                    const SizedBox(width: 10),
                    Text(
                      'FairShare',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => context.go('/profile'),
                  borderRadius: BorderRadius.circular(20),
                  child: UserAvatar(
                    avatarUrl: user?.avatarUrl,
                    name: user?.displayName,
                    userId: user?.id,
                    radius: 20,
                    borderWidth: 1,
                    borderColor: colors.border,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),

          // Centered Net Balance Display
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentPill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Text(
                    'PERSONAL • NET BALANCE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  formattedTotal,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: colors.textMain,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusDotColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Frosted Action Buttons Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _FrostedActionButton(
                icon: Icons.add_rounded,
                label: 'Add',
                onTap: onAddExpense,
              ),
              _FrostedActionButton(
                icon: Icons.receipt_long_rounded,
                label: 'Scan Receipt',
                onTap: onScanReceipt,
              ),
              _FrostedActionButton(
                icon: Icons.login_rounded,
                label: 'Join Group',
                onTap: onJoinGroup,
              ),
              _FrostedActionButton(
                icon: Icons.group_add_rounded,
                label: 'New Group',
                onTap: onCreateGroup,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FrostedActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FrostedActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? colors.accentPill : Colors.white,
                border: Border.all(color: colors.border, width: 1),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 26,
                  color: colors.cyan,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

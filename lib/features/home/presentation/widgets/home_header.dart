import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/theme_gradient_header.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    final netBalance = ref.watch(overallNetBalanceProvider);
    final netTotal = netBalance.netTotal;

    String initial = 'U';
    if (user != null && user.fullName.trim().isNotEmpty) {
      initial = user.fullName.trim().substring(0, 1).toUpperCase();
    }

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

    return ThemeGradientHeader(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: AppLogo, App Name & Profile Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const AppLogo(size: 32, withShadow: true, withGlow: true),
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
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? colors.accentPill : Colors.white,
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                      ? Image.network(
                          user.avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(
                            child: Text(
                              initial,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.textMain,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: colors.textMain,
                            ),
                          ),
                        ),
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

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

    // Sleek, widescreen horizontal layout for desktop
    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: Border(
            bottom: BorderSide(color: colors.border, width: 1),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
            colors: [
              colors.surface,
              colors.surfaceElevated.withValues(alpha: 0.65),
              colors.gradStart.withValues(alpha: 0.22),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Welcome Greeting on Left, Sleek Action Buttons on Right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${user?.displayName ?? 'Friend'}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: colors.textMain,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
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
                ),
                const SizedBox(width: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _DesktopHeaderButton(
                      icon: Icons.add_rounded,
                      label: 'Add Expense',
                      isPrimary: true,
                      onTap: onAddExpense,
                    ),
                    _DesktopHeaderButton(
                      icon: Icons.receipt_long_rounded,
                      label: 'Scan Receipt',
                      onTap: onScanReceipt,
                    ),
                    _DesktopHeaderButton(
                      icon: Icons.group_add_rounded,
                      label: 'New Group',
                      onTap: onCreateGroup,
                    ),
                    _DesktopHeaderButton(
                      icon: Icons.login_rounded,
                      label: 'Join Group',
                      onTap: onJoinGroup,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Horizontal Metrics Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: colors.surfaceElevated.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Row(
                children: [
                  // Net Balance Metric
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: statusDotColor.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            netTotal > 0.01
                                ? Icons.arrow_downward_rounded
                                : netTotal < -0.01
                                    ? Icons.arrow_upward_rounded
                                    : Icons.check_rounded,
                            color: statusDotColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PERSONAL • NET BALANCE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedTotal,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: colors.textMain,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1,
                    height: 42,
                    color: colors.border,
                  ),
                  const SizedBox(width: 20),

                  // Status explanation
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusDotColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
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
      );
    }

    return ThemeGradientHeader(
      borderRadius: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

class _DesktopHeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _DesktopHeaderButton({
    required this.icon,
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.cyan,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: colors.cyan),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.textMain,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: colors.surfaceElevated.withValues(alpha: isDark ? 0.6 : 1.0),
        side: BorderSide(color: colors.border, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}


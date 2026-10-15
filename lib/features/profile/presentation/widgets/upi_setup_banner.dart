import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../data/providers/auth_provider.dart';
import 'set_upi_sheet.dart';

/// Non-intrusive reminder banner encouraging users without a configured UPI ID
/// to complete their profile setup for seamless 1-tap settlements.
class UpiSetupBanner extends ConsumerWidget {
  final EdgeInsetsGeometry? margin;

  const UpiSetupBanner({
    super.key,
    this.margin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final user = ref.watch(currentUserProvider);

    if (user == null) return const SizedBox.shrink();
    final hasVpa = user.vpaId != null && user.vpaId!.trim().isNotEmpty;
    if (hasVpa) return const SizedBox.shrink();

    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cyan.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: colors.cyan.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.account_balance_wallet_rounded,
              color: colors.cyan,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Up Your UPI ID',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Add your UPI ID so friends can pay you back directly with one tap.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => SetUpiSheet.show(context, user: user),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: colors.cyan,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add UPI ID',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

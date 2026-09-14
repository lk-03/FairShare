import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/direct_debt.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../expenses/presentation/widgets/settle_up_sheet.dart';

class MemberProfileSheet extends ConsumerWidget {
  final GroupMember member;
  final Group cohort;

  const MemberProfileSheet({
    super.key,
    required this.member,
    required this.cohort,
  });

  static Future<void> show(
    BuildContext context, {
    required GroupMember member,
    required Group cohort,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MemberProfileSheet(
        member: member,
        cohort: cohort,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isSelf = member.userId == currentUser?.id;
    final debts = ref.watch(groupDebtsProvider(cohort.id));

    DirectDebt? mutualDebt;
    bool youOwe = false;

    for (final d in debts) {
      if (d.fromUserId == currentUser?.id && d.toUserId == member.userId) {
        mutualDebt = d;
        youOwe = true;
        break;
      } else if (d.fromUserId == member.userId && d.toUserId == currentUser?.id) {
        mutualDebt = d;
        youOwe = false;
        break;
      }
    }

    final debtAmount = mutualDebt?.amount ?? 0.0;
    final hasDebt = debtAmount > 0.01;
    final vpa = member.profile?.vpaId;

    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height - mediaQuery.padding.top;

    return Container(
      constraints: BoxConstraints(
        maxHeight: availableHeight * 0.88,
      ),
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
          left: BorderSide(color: AppColors.borderSubtle, width: 1),
          right: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderFocus,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Avatar & Name
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.surfaceCard,
                child: Text(
                  (member.displayName.isNotEmpty ? member.displayName[0] : 'U').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSelf ? '${member.displayName} (You)' : member.displayName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Text(
                  '${member.role.toUpperCase()} · ${cohort.name}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bilateral Balance Card
              if (!isSelf) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Text(
                        !hasDebt
                            ? 'ALL SETTLED UP'
                            : (youOwe ? 'YOU OWE THEM' : 'THEY OWE YOU'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: !hasDebt
                              ? AppColors.textMuted
                              : (youOwe ? AppColors.rose : AppColors.emerald),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasDebt ? CurrencyFormatter.format(debtAmount) : '₹0.00',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: !hasDebt
                              ? AppColors.textPrimary
                              : (youOwe ? AppColors.rose : AppColors.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // UPI ID / VPA Row
              if (vpa != null && vpa.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(
                            vpa,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: vpa));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('UPI ID copied to clipboard!')),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.copy_rounded, size: 16, color: AppColors.primaryTeal),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Actions
              if (!isSelf && hasDebt && youOwe && mutualDebt != null)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      SettleUpSheet.show(
                        context,
                        cohortId: cohort.id,
                        debt: mutualDebt!,
                      );
                    },
                    icon: const Icon(Icons.payment_rounded, size: 18),
                    label: const Text('Settle Up Debt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: AppColors.surfaceDim,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';

class HomeRecentActivitySection extends ConsumerWidget {
  final VoidCallback onAddExpense;
  final ValueChanged<Expense> onExpenseTap;

  const HomeRecentActivitySection({
    super.key,
    required this.onAddExpense,
    required this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final groupsAsync = ref.watch(groupsProvider);
    final recentExpenses = ref.watch(allRecentExpensesProvider);
    final currentUser = ref.watch(currentUserProvider);

    final isLoading = groupsAsync.isLoading && recentExpenses.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT ACTIVITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: colors.textSecondary,
              ),
            ),
            if (recentExpenses.isNotEmpty)
              InkWell(
                onTap: () => context.go('/activity'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'See All',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.cyan,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Body
        if (isLoading)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border, width: 1),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
                ),
              ),
            ),
          )
        else if (recentExpenses.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No Recent Activity',
            description:
                'When you or your group members add an expense or split a bill, it will appear here.',
            primaryActionLabel: 'Add an Expense',
            onPrimaryAction: onAddExpense,
            variant: EmptyStateVariant.card,
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentExpenses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = recentExpenses[index];
              final isPaidByMe = currentUser != null && item.paidByUserId == currentUser.id;
              final payerLabel = isPaidByMe ? 'You' : (item.paidByName ?? 'Member');

              return InkWell(
                onTap: () => onExpenseTap(item),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      CategoryIcon(
                        category: item.category,
                        customIcon: item.customIcon,
                        size: 44,
                        variant: CategoryIconVariant.solid,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colors.textMain,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Paid by $payerLabel • ${CurrencyFormatter.format(item.totalAmount)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.format(item.totalAmount),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

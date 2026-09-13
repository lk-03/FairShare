import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import 'add_expense_sheet.dart';

class ExpenseDetailsSheet extends ConsumerWidget {
  final Expense expense;
  final String cohortId;

  const ExpenseDetailsSheet({
    super.key,
    required this.expense,
    required this.cohortId,
  });

  static Future<void> show(
    BuildContext context, {
    required Expense expense,
    required String cohortId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseDetailsSheet(
        expense: expense,
        cohortId: cohortId,
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense?'),
        content: Text('Are you sure you want to delete "${expense.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF43F5E)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(groupExpensesProvider(cohortId).notifier).deleteExpense(expense.id);
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${expense.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete expense: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleEdit(BuildContext context) {
    Navigator.of(context).pop();
    AddExpenseSheet.show(
      context,
      cohortId: cohortId,
      existingExpense: expense,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currentUser = ref.watch(currentUserProvider);
    final members = ref.watch(groupMembersProvider(cohortId));

    final payerMember = members.where((m) => m.userId == expense.paidByUserId).firstOrNull;
    final isCurrentUserPayer = expense.paidByUserId == currentUser?.id;
    final payerDisplayName = isCurrentUserPayer
        ? 'You'
        : (payerMember?.profile?.displayName ?? expense.paidByName);

    final formattedDate = DateFormat('EEEE, MMM d, y • h:mm a').format(expense.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Edit and Delete Icons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back_rounded, color: colors.textSecondary),
              ),
              Text(
                'Expense Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: colors.textMain,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _handleEdit(context),
                    icon: Icon(Icons.edit_outlined, size: 20, color: colors.cyan),
                    tooltip: 'Edit Expense',
                  ),
                  IconButton(
                    onPressed: () => _handleDelete(context, ref),
                    icon: Icon(Icons.delete_outline_rounded, size: 20, color: colors.crimson),
                    tooltip: 'Delete Expense',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Hero Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                CategoryIcon(category: expense.category, size: 40, variant: CategoryIconVariant.solid),
                const SizedBox(height: 12),
                Text(
                  expense.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.formatINR(expense.totalAmount),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: colors.cyan,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paid by $payerDisplayName',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Notes (if any)
          if (expense.notes != null && expense.notes!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.accentPill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 16, color: colors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      expense.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Split Breakdown Section
          Text(
            'SPLIT BREAKDOWN (${expense.splitType.name.toUpperCase()})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: colors.accentPill,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expense.splits.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: colors.border),
              itemBuilder: (context, index) {
                final split = expense.splits[index];
                final isMe = split.userId == currentUser?.id;
                final member = members.where((m) => m.userId == split.userId).firstOrNull;
                final name = isMe ? 'You' : (member?.profile?.displayName ?? 'Member');

                // Determine if this person lent or owes
                final isPayer = split.userId == expense.paidByUserId;

                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: colors.surface,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: colors.cyan,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.textMain,
                      ),
                    ),
                    subtitle: Text(
                      isPayer ? 'Paid and shared' : 'Owes share',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textSecondary,
                      ),
                    ),
                    trailing: Text(
                      CurrencyFormatter.formatINR(split.amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: colors.textMain,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

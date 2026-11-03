import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/direct_debt.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/friend.dart';
import '../../../../core/models/friend_balance.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/friends_provider.dart';
import '../../../expenses/presentation/widgets/add_expense_sheet.dart';
import '../../../expenses/presentation/widgets/expense_details_sheet.dart';
import '../../../expenses/presentation/widgets/settle_up_sheet.dart';

class FriendDetailScreen extends ConsumerStatefulWidget {
  final String friendId;

  const FriendDetailScreen({
    super.key,
    required this.friendId,
  });

  @override
  ConsumerState<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends ConsumerState<FriendDetailScreen> {
  Future<void> _handleDeleteFriend(Friend friend) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text(
          'Are you sure you want to remove ${friend.displayName} from your friends list? Shared expenses will remain recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(friendsProvider.notifier).removeFriend(friend.id);
        if (mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed ${friend.displayName}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove friend: $e'),
              backgroundColor: AppColors.rose,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _handleAddExpense(Friend friend) {
    AddExpenseSheet.show(
      context,
      friendshipId: friend.id,
      friend: friend,
    );
  }

  void _handleSettleUp(Friend friend, FriendBalance balance) {
    final currentUser = ref.read(currentUserProvider);
    final myUserId = currentUser?.id ?? '';
    final isUserOwing = balance.userOwesFriend;

    final debt = DirectDebt(
      fromUserId: isUserOwing ? myUserId : friend.friendUserId,
      fromProfile: isUserOwing ? currentUser : friend.profile,
      toUserId: isUserOwing ? friend.friendUserId : myUserId,
      toProfile: isUserOwing ? friend.profile : currentUser,
      amount: balance.absoluteAmount > 0 ? balance.absoluteAmount : 0.0,
    );

    SettleUpSheet.show(
      context,
      cohortId: friend.id,
      debt: debt,
      isFriendship: true,
    );
  }

  void _handleCopyUpi(String upiId) {
    Clipboard.setData(ClipboardData(text: upiId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied UPI ID "$upiId" to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final friendsAsync = ref.watch(friendsProvider);
    final friends = friendsAsync.value ?? [];
    final friend = friends.where((f) => f.id == widget.friendId || f.friendUserId == widget.friendId).firstOrNull;

    if (friend == null) {
      if (friendsAsync.isLoading) {
        return Scaffold(
          backgroundColor: colors.screen,
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: colors.screen,
        appBar: AppBar(
          backgroundColor: colors.screen,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: colors.textMain),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Friend not found',
            style: TextStyle(color: colors.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final balance = ref.watch(friendBalanceProvider(friend));
    final expensesAsync = ref.watch(friendExpensesProvider(friend.id));
    final expenses = expensesAsync.value ?? [];
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? '';

    return Scaffold(
      backgroundColor: colors.screen,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.cyan,
          onRefresh: () async {
            ref.invalidate(friendsProvider);
            ref.invalidate(friendExpensesProvider(friend.id));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Top App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_rounded, color: colors.textMain),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
                        color: colors.surfaceElevated,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (val) {
                          if (val == 'delete') {
                            _handleDeleteFriend(friend);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.person_remove_outlined, color: AppColors.rose, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  'Remove Friend',
                                  style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Friend Profile Hero Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      UserAvatar(
                        avatarUrl: friend.profile.avatarUrl,
                        name: friend.displayName,
                        userId: friend.friendUserId,
                        radius: 36,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              friend.displayName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: colors.textMain,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (friend.isLocalContact) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: colors.cyan.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.cyan.withValues(alpha: 0.25)),
                              ),
                              child: Text(
                                'OFFLINE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.cyan,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (friend.emailOrHandle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          friend.emailOrHandle,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (friend.upiId != null && friend.upiId!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _handleCopyUpi(friend.upiId!),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.surfaceElevated,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colors.borderSubtle),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.qr_code_rounded, size: 14, color: AppColors.emerald),
                                const SizedBox(width: 6),
                                Text(
                                  friend.upiId!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textMain,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded, size: 12, color: colors.textMuted),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Bilateral Balance Hero Card
                      _buildBalanceHero(balance, colors, friend),

                      const SizedBox(height: 16),

                      // Action Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleAddExpense(friend),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Expense'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.cyan,
                                foregroundColor: Colors.black,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _handleSettleUp(friend, balance),
                              icon: const Icon(Icons.handshake_outlined, size: 18),
                              label: const Text('Settle Up'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colors.textMain,
                                side: BorderSide(color: colors.borderSubtle, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Expenses Section Title
                      Row(
                        children: [
                          Text(
                            'Shared Expenses',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colors.textMain,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${expenses.length} transaction${expenses.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Expenses List or Empty State
              if (expensesAsync.isLoading && expenses.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(colors.cyan),
                      ),
                    ),
                  ),
                )
              else if (expenses.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 28,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Keep track of dinners, cabs, or split items directly with ${friend.displayName}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _handleAddExpense(friend),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Record First Expense'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.surfaceElevated,
                            foregroundColor: colors.cyan,
                            elevation: 0,
                            side: BorderSide(color: colors.cyan.withValues(alpha: 0.3)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final expense = expenses[index];
                        return _buildExpenseTile(
                          expense,
                          colors,
                          currentUserId,
                          friend,
                        );
                      },
                      childCount: expenses.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 40),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceHero(FriendBalance balance, dynamic colors, Friend friend) {
    if (balance.isSettled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 36, color: colors.cyan),
            const SizedBox(height: 8),
            Text(
              'All Settled Up',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You and ${friend.displayName} are even',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final owesYou = balance.owesYou;
    final primaryColor = owesYou ? AppColors.emerald : AppColors.amber;
    final title = owesYou ? '${friend.displayName} owes you' : 'You owe ${friend.displayName}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primaryColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatINR(balance.absoluteAmount),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          if (balance.totalVolume > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Total shared volume: ${CurrencyFormatter.formatINR(balance.totalVolume)}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpenseTile(
    Expense expense,
    dynamic colors,
    String currentUserId,
    Friend friend,
  ) {
    final isUserPayer = expense.paidByUserId == currentUserId;
    final dateStr = DateFormat('MMM d, yyyy').format(expense.createdAt);

    // Calculate user net share
    final mySplit = expense.splits.where((s) => s.userId == currentUserId).firstOrNull;
    final friendSplit = expense.splits.where((s) => s.userId == friend.friendUserId).firstOrNull;

    final String balanceImpactText;
    final Color balanceImpactColor;
    final String subtitleText;

    if (expense.isSettlement) {
      balanceImpactText = 'Settlement';
      balanceImpactColor = colors.cyan;
      subtitleText = isUserPayer
          ? 'You paid ${friend.displayName}'
          : '${friend.displayName} paid you';
    } else if (isUserPayer) {
      final amountLent = friendSplit?.amount ?? (expense.totalAmount - (mySplit?.amount ?? 0));
      balanceImpactText = '+${CurrencyFormatter.formatINR(amountLent)}';
      balanceImpactColor = AppColors.emerald;
      subtitleText = 'You paid ${CurrencyFormatter.formatINR(expense.totalAmount)}';
    } else {
      final amountOwed = mySplit?.amount ?? (expense.totalAmount / 2);
      balanceImpactText = '-${CurrencyFormatter.formatINR(amountOwed)}';
      balanceImpactColor = AppColors.rose;
      subtitleText = '${friend.displayName} paid ${CurrencyFormatter.formatINR(expense.totalAmount)}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ExpenseDetailsSheet.show(
              context,
              expense: expense,
              friendshipId: friend.id,
              friend: friend,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CategoryIcon(category: expense.category, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colors.textMain,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('•', style: TextStyle(fontSize: 10, color: colors.textMuted)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              subtitleText,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      balanceImpactText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: balanceImpactColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatINR(expense.totalAmount),
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textMuted,
                        decoration: expense.isSettlement ? TextDecoration.none : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

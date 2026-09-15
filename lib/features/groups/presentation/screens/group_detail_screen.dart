import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/direct_debt.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../core/models/group_member.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/group_avatar.dart';
import '../../../../data/providers/auth_provider.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../../data/providers/needs_provider.dart';
import '../../../expenses/presentation/widgets/add_expense_sheet.dart';
import '../../../expenses/presentation/widgets/expense_details_sheet.dart';
import '../../../expenses/presentation/widgets/itemized_receipt_sheet.dart';
import '../../../expenses/presentation/widgets/settle_up_sheet.dart';
import '../../../needs/presentation/widgets/needs_list_view.dart';
import '../widgets/edit_group_sheet.dart';
import '../widgets/group_qr_sheet.dart';
import '../widgets/member_profile_sheet.dart';
import '../widgets/monthly_spendings_tab.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _selectedTab = 0; // 0: Ledger, 1: House Cart

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(groupExpensesProvider(widget.groupId).notifier).loadExpenses();
      ref.read(groupNeedsProvider(widget.groupId).notifier).loadNeeds();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(groupExpensesProvider(widget.groupId).notifier).loadExpenses(),
      ref.read(groupNeedsProvider(widget.groupId).notifier).loadNeeds(),
    ]);
  }

  void _handleAddExpense() {
    AddExpenseSheet.show(context, cohortId: widget.groupId);
  }

  void _handleExpenseTap(Expense expense) {
    ExpenseDetailsSheet.show(
      context,
      expense: expense,
      cohortId: widget.groupId,
    );
  }

  void _handleSettleUp(DirectDebt debt) {
    SettleUpSheet.show(
      context,
      cohortId: widget.groupId,
      debt: debt,
    );
  }

  void _handleShowQR(Group group) {
    GroupQrSheet.show(context, group);
  }

  void _handleEditGroup(Group group) {
    EditGroupSheet.show(
      context,
      group,
      onDeleted: () {
        if (mounted) context.go('/home');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final groups = ref.watch(groupsProvider).value ?? [];
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;

    if (group == null) {
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
            'Group not found',
            style: TextStyle(color: colors.textSecondary, fontSize: 16),
          ),
        ),
      );
    }

    final members = ref.watch(groupMembersProvider(widget.groupId));
    final expensesAsync = ref.watch(groupExpensesProvider(widget.groupId));
    final expenses = expensesAsync.value ?? [];
    final debts = ref.watch(groupDebtsProvider(widget.groupId));
    final userBalance = ref.watch(userNetBalanceProvider(widget.groupId));
    final totalSpent = ref.watch(groupTotalSpendingProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider);

    final needs = ref.watch(groupNeedsProvider(widget.groupId)).value ?? [];
    final pendingNeeds = needs.where((n) => !n.isCompleted).length;

    return Scaffold(
      backgroundColor: colors.screen,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            _buildTopBar(group, colors),

            // Segmented Sub-Tab Switcher
            _buildSubTabSelector(colors, pendingNeeds),

            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: colors.cyan,
                backgroundColor: colors.surface,
                child: _selectedTab == 0
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Group Net Balance Hero Card
                            _buildBalanceHero(group, userBalance, totalSpent, colors),
                            const SizedBox(height: 20),

                            // Horizontal Member Rail
                            _buildMemberRail(members, group, currentUser?.id, colors),
                            const SizedBox(height: 24),

                            // Debts to Settle Section
                            _buildDebtsSection(debts, currentUser?.id, colors),
                            const SizedBox(height: 24),

                            // Chronological Expenses Section
                            _buildExpensesSection(expenses, currentUser?.id, colors),
                            const SizedBox(height: 80), // Padding for floating button
                          ],
                        ),
                      )
                    : _selectedTab == 1
                        ? MonthlySpendingsTab(
                            cohort: group,
                            expenses: expenses,
                            members: members,
                            currentUserId: currentUser?.id ?? '',
                          )
                        : SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                NeedsListView(cohortId: widget.groupId),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: _handleAddExpense,
              backgroundColor: colors.cyan,
              foregroundColor: const Color(0xFF0F172A),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'Add Expense',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSubTabSelector(AppThemeColors colors, int pendingNeeds) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSubTabItem(
              title: 'General Ledger',
              icon: Icons.receipt_long_rounded,
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
              colors: colors,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSubTabItem(
              title: 'Spendings',
              icon: Icons.pie_chart_outline_rounded,
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
              colors: colors,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSubTabItem(
              title: 'House Cart',
              icon: Icons.shopping_cart_outlined,
              badgeCount: pendingNeeds,
              isSelected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
              colors: colors,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeColors colors,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.cyan.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colors.cyan.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.cyan : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? colors.cyan : colors.textSecondary,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected ? colors.cyan : colors.accentPill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : colors.cyan,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Group group, AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.screen,
        border: Border(bottom: BorderSide(color: colors.border.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_rounded, color: colors.textMain),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          GroupAvatar(
            avatarUrl: group.avatarUrl,
            category: group.category,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  group.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.textMain,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      group.category[0].toUpperCase() + group.category.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${group.members.length} members',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ItemizedReceiptSheet.show(context),
            icon: Icon(Icons.document_scanner_rounded, color: colors.cyan),
            tooltip: 'Scan Receipt',
          ),
          IconButton(
            onPressed: () => _handleShowQR(group),
            icon: Icon(Icons.qr_code_rounded, color: colors.cyan),
            tooltip: 'Invite QR Code',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: colors.textSecondary),
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.border),
            ),
            onSelected: (action) {
              if (action == 'edit') {
                _handleEditGroup(group);
              } else if (action == 'qr') {
                _handleShowQR(group);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Text('Edit Group', style: TextStyle(fontSize: 13, color: colors.textMain)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 18, color: colors.textSecondary),
                    const SizedBox(width: 10),
                    Text('Invite Members', style: TextStyle(fontSize: 13, color: colors.textMain)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceHero(
    Group group,
    double userBalance,
    double totalSpent,
    AppThemeColors colors,
  ) {
    final isSettled = userBalance.abs() < 0.01;
    final isOwed = userBalance > 0.01;
    final balanceColor = isSettled
        ? colors.textSecondary
        : (isOwed ? colors.emerald : colors.crimson);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YOUR GROUP BALANCE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: colors.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accentPill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Total Spend: ${CurrencyFormatter.formatINR(totalSpent)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: colors.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isSettled
                ? '₹0.00'
                : (isOwed
                    ? '+${CurrencyFormatter.formatINR(userBalance)}'
                    : '-${CurrencyFormatter.formatINR(userBalance.abs())}'),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: balanceColor,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: balanceColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isSettled
                    ? 'You are all settled up in this cohort'
                    : (isOwed
                        ? 'You are owed ${CurrencyFormatter.formatINR(userBalance)} in total'
                        : 'You owe ${CurrencyFormatter.formatINR(userBalance.abs())} in total'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRail(
    List<GroupMember> members,
    Group group,
    String? currentUserId,
    AppThemeColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'MEMBERS (${members.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: members.map((m) {
              final isMe = m.userId == currentUserId;
              final name = isMe ? 'You' : (m.profile?.displayName ?? 'Member');
              final isAdmin = m.role == 'admin';

              return InkWell(
                onTap: () => MemberProfileSheet.show(context, member: m, cohort: group),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 90,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: colors.accentPill,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colors.cyan,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: colors.textMain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isAdmin ? 'Admin' : 'Member',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDebtsSection(
    List<DirectDebt> debts,
    String? currentUserId,
    AppThemeColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DEBTS TO SETTLE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
            if (debts.isNotEmpty)
              Text(
                'Min-Flow Simplified',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.cyan,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (debts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: colors.emerald, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All settled up! No outstanding balances between members.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...debts.map((debt) {
            final isMePayer = debt.fromUserId == currentUserId;
            final isMePayee = debt.toUserId == currentUserId;

            final payerName = isMePayer
                ? 'You'
                : (debt.fromProfile?.displayName ?? 'A member');
            final payeeName = isMePayee
                ? 'You'
                : (debt.toProfile?.displayName ?? 'A member');

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isMePayer
                        ? colors.crimson.withValues(alpha: 0.15)
                        : colors.accentPill,
                    child: Text(
                      payerName.isNotEmpty ? payerName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isMePayer ? colors.crimson : colors.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: colors.textMain),
                            children: [
                              TextSpan(
                                text: payerName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const TextSpan(text: ' owes '),
                              TextSpan(
                                text: payeeName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatINR(debt.amount),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: colors.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleSettleUp(debt),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.cyan,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Settle Up',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildExpensesSection(
    List<Expense> expenses,
    String? currentUserId,
    AppThemeColors colors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EXPENSES (${expenses.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (expenses.isEmpty)
          EmptyState(
            title: 'No Expenses Yet',
            description: 'Log group purchases, bills, and tickets to start splitting fairly.',
            primaryActionLabel: 'Add Expense',
            onPrimaryAction: _handleAddExpense,
          )
        else
          ...expenses.map((exp) {
            final isSettlement = exp.category == 'settlement';
            final formattedDate = DateFormat('MMM d, h:mm a').format(exp.createdAt);
            final userSplit = exp.splits.where((s) => s.userId == currentUserId).firstOrNull;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: ListTile(
                onTap: () => _handleExpenseTap(exp),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: CategoryIcon(
                  category: exp.category,
                  size: 26,
                  variant: CategoryIconVariant.solid,
                ),
                title: Text(
                  exp.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: colors.textMain,
                  ),
                ),
                subtitle: Text(
                  '${exp.paidByName} • $formattedDate',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatINR(exp.totalAmount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isSettlement ? colors.emerald : colors.textMain,
                      ),
                    ),
                    if (userSplit != null && !isSettlement)
                      Text(
                        'Your share: ${CurrencyFormatter.formatINR(userSplit.amount)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.cyan,
                        ),
                      ),
                  ],
                ),
              ),
              ),
            );
          }),
      ],
    );
  }
}

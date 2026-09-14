import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/activity_item.dart';
import '../../../../core/models/expense_shortcut.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/category_icon.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/theme_gradient_header.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import '../../../expenses/presentation/widgets/expense_details_sheet.dart';

enum ActivityFilter { all, expenses, comments }

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final TextEditingController _searchController = TextEditingController();
  ActivityFilter _selectedFilter = ActivityFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await ref.read(groupsProvider.notifier).loadUserGroups();
    final groups = ref.read(groupsProvider).value ?? [];
    await Future.wait(
      groups.map((g) => ref.read(groupExpensesProvider(g.id).notifier).loadExpenses()),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }

  void _handleItemTap(ActivityItem item) {
    if (item.rawExpense != null) {
      ExpenseDetailsSheet.show(
        context,
        expense: item.rawExpense!,
        cohortId: item.cohortId,
      );
    } else {
      context.push('/groups/${item.cohortId}');
    }
  }

  void _handleItemLongPress(ActivityItem item) {
    if (item.type != ActivityType.expense || item.rawExpense == null) return;
    final exp = item.rawExpense!;
    final colors = context.colors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Item Header
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.textMain,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Amount: ${CurrencyFormatter.formatINR(item.amount ?? 0)} • ${item.cohortName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Action: Save as Shortcut
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.accentPill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.bookmark_outline_rounded, color: colors.cyan, size: 20),
                  ),
                  title: Text(
                    'Save as Shortcut',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                  ),
                  subtitle: Text(
                    'Save to ${item.cohortName} presets for 1-tap re-use',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final shortcut = ExpenseShortcut(
                      id: 'sc_${DateTime.now().millisecondsSinceEpoch}',
                      cohortId: item.cohortId,
                      title: exp.title,
                      category: exp.category,
                      customIcon: exp.customIcon,
                      amount: exp.totalAmount,
                      paidByUserId: exp.paidByUserId,
                      splitType: exp.splitType.name,
                      includedMemberIds: exp.splits.map((s) => s.userId).toList(),
                      createdAt: DateTime.now(),
                    );
                    await ref
                        .read(expenseShortcutsProvider(item.cohortId).notifier)
                        .addShortcut(shortcut);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"${exp.title}" saved to ${item.cohortName} shortcuts!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  },
                ),

                const Divider(height: 16),

                // Action: Go to Group
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.accentPill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_forward_rounded, color: colors.cyan, size: 20),
                  ),
                  title: Text(
                    'Go to Group',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                  ),
                  subtitle: Text(
                    'View ${item.cohortName} ledger and expenses',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/groups/${item.cohortId}');
                  },
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final allItems = ref.watch(activityFeedProvider);

    // Counts for filter chips
    final expensesCount =
        allItems.where((i) => i.type == ActivityType.expense).length;
    final commentsCount =
        allItems.where((i) => i.type == ActivityType.comment).length;

    // Filter items
    final filteredItems = allItems.where((item) {
      // Type filter
      if (_selectedFilter == ActivityFilter.expenses &&
          item.type != ActivityType.expense) {
        return false;
      }
      if (_selectedFilter == ActivityFilter.comments &&
          item.type != ActivityType.comment) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final titleMatch = item.title.toLowerCase().contains(_searchQuery);
        final metaMatch = item.meta.toLowerCase().contains(_searchQuery);
        final cohortMatch = item.cohortName.toLowerCase().contains(_searchQuery);
        final commentMatch = item.commentContent != null &&
            item.commentContent!.toLowerCase().contains(_searchQuery);
        return titleMatch || metaMatch || cohortMatch || commentMatch;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: colors.screen,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: colors.cyan,
        backgroundColor: colors.surface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Revolut Gradient Header
            SliverToBoxAdapter(
              child: ThemeGradientHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: colors.textMain,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Global Ledger Audit & Expense Timeline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Sticky Search & Filter Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: colors.textMain, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search activity, groups, or comments...',
                          hintStyle: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: colors.textSecondary,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    color: colors.textSecondary,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterPill(
                            title: 'All (${allItems.length})',
                            isSelected: _selectedFilter == ActivityFilter.all,
                            onTap: () => setState(
                                () => _selectedFilter = ActivityFilter.all),
                            colors: colors,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            title: 'Expenses ($expensesCount)',
                            isSelected:
                                _selectedFilter == ActivityFilter.expenses,
                            onTap: () => setState(() =>
                                _selectedFilter = ActivityFilter.expenses),
                            colors: colors,
                          ),
                          const SizedBox(width: 8),
                          _buildFilterPill(
                            title: 'Comments ($commentsCount)',
                            isSelected:
                                _selectedFilter == ActivityFilter.comments,
                            onTap: () => setState(() =>
                                _selectedFilter = ActivityFilter.comments),
                            colors: colors,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Label
                    Text(
                      'RECENT TIMELINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Feed
            if (filteredItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyState(
                    icon: Icons.history_rounded,
                    title: _searchQuery.isNotEmpty
                        ? 'No matching activity'
                        : 'No recent activity',
                    description: _searchQuery.isNotEmpty
                        ? 'Try modifying your search or clearing active filters.'
                        : 'Expenses and discussion comments across your cohorts will appear here.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = filteredItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildActivityCard(item, colors),
                      );
                    },
                    childCount: filteredItems.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required AppThemeColors colors,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? colors.cyan.withValues(alpha: 0.15) : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.cyan : colors.border,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? colors.cyan : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityItem item, AppThemeColors colors) {
    return InkWell(
      onTap: () => _handleItemTap(item),
      onLongPress: () => _handleItemLongPress(item),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            // Leading Icon
            if (item.type == ActivityType.comment)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accentPill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: colors.cyan,
                ),
              )
            else if (item.type == ActivityType.system)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.accentPill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  size: 20,
                  color: colors.cyan,
                ),
              )
            else
              CategoryIcon(
                category: item.category ?? 'other',
                customIcon: item.customIcon,
                size: 44,
                variant: CategoryIconVariant.solid,
              ),

            const SizedBox(width: 12),

            // Middle Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.meta} • ${item.cohortName}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimeAgo(item.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Trailing Amount or Navigation Arrow
            if (item.amount != null)
              Text(
                CurrencyFormatter.formatINR(item.amount!),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.textMain,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

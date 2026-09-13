import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/expense.dart';
import '../../../../core/models/group.dart';
import '../../../../data/providers/expenses_provider.dart';
import '../../../../data/providers/groups_provider.dart';
import '../widgets/create_group_sheet.dart';
import '../widgets/home_groups_section.dart';
import '../widgets/home_header.dart';
import '../widgets/home_recent_activity_section.dart';
import '../widgets/join_group_sheet.dart';
import '../widgets/select_group_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _syncBannerError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      await ref.read(groupsProvider.notifier).loadUserGroups();
      final groups = ref.read(groupsProvider).value ?? [];
      for (final cohort in groups) {
        ref.read(groupExpensesProvider(cohort.id).notifier).loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncBannerError = 'Offline mode: using cached data.');
      }
    }
  }

  void _handleAddExpense() {
    final groups = ref.read(groupsProvider).value ?? [];
    final activeCohorts = groups.where((c) => !c.isDeleted).toList();

    if (activeCohorts.isEmpty) {
      _handleCreateGroup();
    } else if (activeCohorts.length == 1) {
      _openAddExpenseForGroup(activeCohorts.first);
    } else {
      SelectGroupSheet.show(
        context,
        onCreateNewGroup: _handleCreateGroup,
      ).then((selected) {
        if (selected != null) {
          _openAddExpenseForGroup(selected);
        }
      });
    }
  }

  void _handleScanReceipt() {
    final groups = ref.read(groupsProvider).value ?? [];
    final activeCohorts = groups.where((c) => !c.isDeleted).toList();

    if (activeCohorts.isEmpty) {
      _handleCreateGroup();
    } else if (activeCohorts.length == 1) {
      _openScanReceiptForGroup(activeCohorts.first);
    } else {
      SelectGroupSheet.show(
        context,
        onCreateNewGroup: _handleCreateGroup,
      ).then((selected) {
        if (selected != null) {
          _openScanReceiptForGroup(selected);
        }
      });
    }
  }

  void _openAddExpenseForGroup(Group group) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add expense for "${group.name}" selected.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openScanReceiptForGroup(Group group) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Receipt scanner for "${group.name}" selected.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleJoinGroup() {
    JoinGroupSheet.show(
      context,
      onScanQr: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code scanner opening...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _handleCreateGroup() {
    CreateGroupSheet.show(context);
  }

  void _handleImportSplitwise() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Splitwise CSV import will be available in next release.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleGroupTap(Group cohort) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening group: ${cohort.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExpenseTap(Expense expense) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Expense: ${expense.title}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.screen,
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: colors.cyan,
        backgroundColor: colors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Revolut-style Nordic Blue Header
              HomeHeader(
                onAddExpense: _handleAddExpense,
                onScanReceipt: _handleScanReceipt,
                onJoinGroup: _handleJoinGroup,
                onCreateGroup: _handleCreateGroup,
              ),

              // Offline/Sync Banner
              if (_syncBannerError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 18,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _syncBannerError!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                          onPressed: () => setState(() => _syncBannerError = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Surface Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Groups horizontal section
                    HomeGroupsSection(
                      onCreateGroup: _handleCreateGroup,
                      onJoinGroup: _handleJoinGroup,
                      onImportSplitwise: _handleImportSplitwise,
                      onGroupTap: _handleGroupTap,
                    ),
                    const SizedBox(height: 28),

                    // Recent activity section
                    HomeRecentActivitySection(
                      onAddExpense: _handleAddExpense,
                      onExpenseTap: _handleExpenseTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

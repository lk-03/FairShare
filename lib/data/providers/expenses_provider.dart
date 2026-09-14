import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/algorithms/debt_simplifier.dart';
import '../../core/models/activity_item.dart';
import '../../core/models/comment.dart';
import '../../core/models/direct_debt.dart';
import '../../core/models/expense.dart';
import '../../core/models/expense_shortcut.dart';
import '../repositories/expense_repository.dart';
import 'auth_provider.dart';
import 'groups_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  final profileRepo = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(localCacheServiceProvider);
  return ExpenseRepository(
    supabaseService: supabase,
    profileRepository: profileRepo,
    cacheService: cache,
  );
});

class GroupExpensesNotifier
    extends Notifier<AsyncValue<List<Expense>>> {
  late final String _cohortId;

  GroupExpensesNotifier(String cohortId) {
    _cohortId = cohortId;
  }

  @override
  AsyncValue<List<Expense>> build() {
    final cache = ref.watch(localCacheServiceProvider);
    final cached = cache.getCachedExpenses(_cohortId);
    return AsyncValue.data(cached);
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final expenses = await repo.fetchExpensesForCohort(_cohortId);
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Expense> addExpense(Expense expense) async {
    final repo = ref.read(expenseRepositoryProvider);
    final saved = await repo.createExpense(expense);
    final current = state.value ?? [];
    state = AsyncValue.data([saved, ...current.where((e) => e.id != saved.id)]);
    return saved;
  }

  Future<Expense> updateExpense(Expense expense) async {
    final repo = ref.read(expenseRepositoryProvider);
    final saved = await repo.updateExpense(expense);
    final current = state.value ?? [];
    state = AsyncValue.data(current.map((e) => e.id == saved.id ? saved : e).toList());
    return saved;
  }

  Future<void> deleteExpense(String expenseId) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.deleteExpense(expenseId, _cohortId);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((e) => e.id != expenseId).toList());
  }
}

final groupExpensesProvider =
    NotifierProvider.family<GroupExpensesNotifier, AsyncValue<List<Expense>>, String>(
  (cohortId) => GroupExpensesNotifier(cohortId),
);

/// Computes simplified min-flow direct debt settlements for a cohort
final groupDebtsProvider =
    Provider.family<List<DirectDebt>, String>((ref, cohortId) {
  final expenses = ref.watch(groupExpensesProvider(cohortId)).value ?? [];
  final members = ref.watch(groupMembersProvider(cohortId));

  final result = DebtSimplifier.calculateSimplifiedDebts(
    cohortId: cohortId,
    members: members,
    expenses: expenses,
  );
  return result.simplifiedDebts;
});

/// Total amount spent in a group across all expenses
final groupTotalSpendingProvider =
    Provider.family<double, String>((ref, cohortId) {
  final expenses = ref.watch(groupExpensesProvider(cohortId)).value ?? [];
  return expenses.fold(0.0, (sum, e) => sum + e.totalAmount);
});

/// Net balance for current user in a specific group (+ is owed, - owes)
final userNetBalanceProvider =
    Provider.family<double, String>((ref, cohortId) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return 0.0;

  final expenses = ref.watch(groupExpensesProvider(cohortId)).value ?? [];
  return expenses.fold(0.0, (sum, e) => sum + e.userNetBalance(currentUser.id));
});

/// Net balance totals across all active, non-archived groups for current user
class OverallNetBalance {
  final double totalOwed;
  final double totalOwe;
  final double netTotal;

  const OverallNetBalance({
    this.totalOwed = 0.0,
    this.totalOwe = 0.0,
    this.netTotal = 0.0,
  });
}

final overallNetBalanceProvider = Provider<OverallNetBalance>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return const OverallNetBalance();

  final groups = ref.watch(groupsProvider).value ?? [];
  final activeCohorts =
      groups.where((c) => !c.isDeleted && !c.isArchived).toList();

  double owed = 0.0;
  double owe = 0.0;

  for (final cohort in activeCohorts) {
    final expenses = ref.watch(groupExpensesProvider(cohort.id)).value ?? [];
    final members = ref.watch(groupMembersProvider(cohort.id));
    final res = DebtSimplifier.calculateSimplifiedDebts(
      cohortId: cohort.id,
      members: members,
      expenses: expenses,
    );
    final userBal = res.netBalances[currentUser.id] ?? 0.0;
    if (userBal > 0.01) {
      owed += userBal;
    } else if (userBal < -0.01) {
      owe += userBal.abs();
    }
  }

  return OverallNetBalance(
    totalOwed: owed,
    totalOwe: owe,
    netTotal: owed - owe,
  );
});

/// Recent expenses gathered and sorted across all active cohorts
final allRecentExpensesProvider = Provider<List<Expense>>((ref) {
  final groups = ref.watch(groupsProvider).value ?? [];
  final activeCohorts = groups.where((c) => !c.isDeleted).toList();

  final List<Expense> all = [];
  for (final cohort in activeCohorts) {
    final exps = ref.watch(groupExpensesProvider(cohort.id)).value ?? [];
    all.addAll(exps);
  }

  all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return all.take(5).toList();
});

/// Aggregated activity feed gathered across all active cohorts where user is involved
final activityFeedProvider = Provider<List<ActivityItem>>((ref) {
  final groups = ref.watch(groupsProvider).value ?? [];
  final activeCohorts = groups.where((c) => !c.isDeleted).toList();
  final currentUser = ref.watch(currentUserProvider);

  final List<ActivityItem> feed = [];

  for (final cohort in activeCohorts) {
    final members = ref.watch(groupMembersProvider(cohort.id));
    final exps = ref.watch(groupExpensesProvider(cohort.id)).value ?? [];

    for (final exp in exps) {
      final isPayer = currentUser != null && exp.paidByUserId == currentUser.id;
      final isSplitter = currentUser != null &&
          exp.splits.any((s) => s.userId == currentUser.id);

      // Include if user is involved, or if currentUser is null (preview/mock mode)
      if (currentUser == null || isPayer || isSplitter) {
        final payerMember =
            members.where((m) => m.userId == exp.paidByUserId).firstOrNull;
        final payerName = (currentUser != null && exp.paidByUserId == currentUser.id)
            ? 'You'
            : (payerMember?.profile?.displayName ?? exp.paidByName ?? 'Member');

        feed.add(ActivityItem(
          id: 'exp_${exp.id}',
          type: ActivityType.expense,
          timestamp: exp.createdAt,
          cohortId: cohort.id,
          cohortName: cohort.name,
          title: exp.title,
          amount: exp.totalAmount,
          meta: '$payerName added a new expense',
          category: exp.category,
          customIcon: exp.customIcon,
          rawExpense: exp,
        ));
      }

      // Check comments for this expense
      final comments =
          ref.watch(expenseCommentsProvider(exp.id)).value ?? [];
      for (final comment in comments) {
        final isUserComment =
            currentUser != null && comment.userId == currentUser.id;
        if (currentUser == null || isUserComment || isPayer || isSplitter) {
          final commenterMember =
              members.where((m) => m.userId == comment.userId).firstOrNull;
          final commenterName =
              (currentUser != null && comment.userId == currentUser.id)
                  ? 'You'
                  : (commenterMember?.profile?.displayName ??
                      comment.profile?.displayName ??
                      'Member');

          feed.add(ActivityItem(
            id: 'com_${comment.id}',
            type: ActivityType.comment,
            timestamp: comment.createdAt,
            cohortId: cohort.id,
            cohortName: cohort.name,
            title: exp.title,
            amount: null,
            meta: '$commenterName commented: "${comment.content}"',
            category: 'comment',
            rawExpense: exp,
            commentId: comment.id,
            commentContent: comment.content,
          ));
        }
      }
    }
  }

  feed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return feed;
});

// --- Expense Comments ---

class ExpenseCommentsNotifier
    extends Notifier<AsyncValue<List<TransactionComment>>> {
  late final String _expenseId;

  ExpenseCommentsNotifier(String expenseId) {
    _expenseId = expenseId;
  }

  @override
  AsyncValue<List<TransactionComment>> build() {
    final cache = ref.watch(localCacheServiceProvider);
    return AsyncValue.data(cache.getCachedComments(_expenseId));
  }

  Future<void> loadComments() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final comments = await repo.fetchCommentsForExpense(_expenseId);
      state = AsyncValue.data(comments);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<TransactionComment> addComment(String content) async {
    final currentUser = ref.read(currentUserProvider);
    final repo = ref.read(expenseRepositoryProvider);

    final newComment = TransactionComment(
      id: 'comm_${DateTime.now().millisecondsSinceEpoch}',
      expenseId: _expenseId,
      userId: currentUser?.id ?? '',
      content: content,
      createdAt: DateTime.now(),
      profile: currentUser,
    );

    final saved = await repo.addComment(newComment);
    final current = state.value ?? [];
    state = AsyncValue.data([...current, saved]);
    return saved;
  }
}

final expenseCommentsProvider = NotifierProvider.family<
    ExpenseCommentsNotifier, AsyncValue<List<TransactionComment>>, String>(
  (expenseId) => ExpenseCommentsNotifier(expenseId),
);

// --- Expense Shortcuts ---

class ExpenseShortcutsNotifier
    extends Notifier<AsyncValue<List<ExpenseShortcut>>> {
  late final String _cohortId;

  ExpenseShortcutsNotifier(String cohortId) {
    _cohortId = cohortId;
  }

  @override
  AsyncValue<List<ExpenseShortcut>> build() {
    final cache = ref.watch(localCacheServiceProvider);
    return AsyncValue.data(cache.getCachedShortcuts(_cohortId));
  }

  Future<void> loadShortcuts() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(expenseRepositoryProvider);
      final shortcuts = await repo.fetchShortcuts(_cohortId);
      state = AsyncValue.data(shortcuts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ExpenseShortcut> addShortcut(ExpenseShortcut shortcut) async {
    final repo = ref.read(expenseRepositoryProvider);
    final saved = await repo.createShortcut(shortcut);
    final current = state.value ?? [];
    state = AsyncValue.data([...current, saved]);
    return saved;
  }

  Future<void> deleteShortcut(String shortcutId) async {
    final repo = ref.read(expenseRepositoryProvider);
    await repo.deleteShortcut(shortcutId, _cohortId);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((s) => s.id != shortcutId).toList());
  }
}

final expenseShortcutsProvider = NotifierProvider.family<
    ExpenseShortcutsNotifier, AsyncValue<List<ExpenseShortcut>>, String>(
  (cohortId) => ExpenseShortcutsNotifier(cohortId),
);

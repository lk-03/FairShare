import '../../core/models/expense.dart';
import '../../core/models/split.dart';
import '../../core/models/comment.dart';
import '../../core/models/expense_shortcut.dart';
import '../../core/models/profile.dart';
import '../local/local_cache_service.dart';
import '../services/supabase_service.dart';
import 'profile_repository.dart';

class ExpenseRepository {
  final SupabaseService supabaseService;
  final ProfileRepository profileRepository;
  final LocalCacheService cacheService;

  ExpenseRepository({
    required this.supabaseService,
    required this.profileRepository,
    required this.cacheService,
  });

  /// Fetches all expenses and their associated splits for a specific cohort
  Future<List<Expense>> fetchExpensesForCohort(String cohortId) async {
    if (!supabaseService.isConfigured || !isUuid(cohortId)) {
      return cacheService.getCachedExpenses(cohortId);
    }

    try {
      final expenseRows = await supabaseService.client
          .from('expenses')
          .select('*')
          .eq('cohort_id', cohortId)
          .order('created_at', ascending: false);

      final rows = (expenseRows as List);
      if (rows.isEmpty) {
        await cacheService.saveExpenses(cohortId, []);
        return [];
      }

      final expenseIds = rows
          .map((r) => r['id'] as String?)
          .whereType<String>()
          .toList();

      // Fetch splits for these expenses
      final splitRows = await supabaseService.client
          .from('expense_splits')
          .select('*')
          .inFilter('expense_id', expenseIds);

      final Map<String, List<ExpenseSplit>> splitsByExpense = {};
      for (final s in (splitRows as List)) {
        final raw = s as Map<String, dynamic>;
        final expId = raw['expense_id'] as String? ?? '';
        final split = ExpenseSplit(
          userId: raw['user_id'] as String? ?? '',
          amount: (raw['amount'] as num?)?.toDouble() ?? 0.0,
          percentage: (raw['percentage'] as num?)?.toDouble(),
        );
        splitsByExpense.putIfAbsent(expId, () => []).add(split);
      }

      final List<Expense> expenses = rows.map((e) {
        final raw = e as Map<String, dynamic>;
        final id = raw['id'] as String;
        final splits = splitsByExpense[id] ?? [];
        return Expense.fromJson({
          ...raw,
          'splits': splits.map((s) => s.toJson()).toList(),
        });
      }).toList();

      await cacheService.saveExpenses(cohortId, expenses);
      return expenses;
    } catch (_) {
      return cacheService.getCachedExpenses(cohortId);
    }
  }

  /// Creates a new expense and its split allocations
  Future<Expense> createExpense(Expense expense) async {
    String paidByUserId = expense.paidByUserId;
    if (!isUuid(paidByUserId)) {
      final profile = await profileRepository.getCurrentProfile();
      paidByUserId = profile.id;
    }

    final effectiveExpense = expense.copyWith(paidByUserId: paidByUserId);

    // Optimistically update local cache
    final currentExpenses = cacheService.getCachedExpenses(expense.cohortId);
    await cacheService.saveExpenses(
      expense.cohortId,
      [effectiveExpense, ...currentExpenses],
    );

    if (!supabaseService.isConfigured || !isUuid(expense.cohortId)) {
      return effectiveExpense;
    }

    try {
      final insertPayload = <String, dynamic>{
        if (isUuid(expense.id)) 'id': expense.id,
        'cohort_id': expense.cohortId,
        'title': expense.title,
        'category': expense.category,
        'custom_icon': expense.customIcon,
        'total_amount': expense.totalAmount,
        'currency': expense.currency,
        'paid_by_user_id': paidByUserId,
        'split_type': expense.splitType.toDbString(),
        'receipt_url': expense.receiptUrl,
        'ocr_parsed': expense.ocrParsed,
        'notes': expense.notes,
      };

      final expRow = await supabaseService.client
          .from('expenses')
          .insert(insertPayload)
          .select()
          .single();

      final savedId = expRow['id'] as String;

      // Insert splits
      if (expense.splits.isNotEmpty) {
        final splitPayloads = expense.splits
            .where((s) => isUuid(s.userId))
            .map((s) => {
                  'expense_id': savedId,
                  'user_id': s.userId,
                  'amount': s.amount,
                  if (s.percentage != null) 'percentage': s.percentage,
                })
            .toList();

        if (splitPayloads.isNotEmpty) {
          await supabaseService.client
              .from('expense_splits')
              .insert(splitPayloads);
        }
      }

      final savedExpense = Expense.fromJson({
        ...expRow,
        'splits': expense.splits.map((s) => s.toJson()).toList(),
      });

      // Update cache with server-saved record
      final updatedExpenses = currentExpenses
          .where((e) => e.id != expense.id && e.id != savedExpense.id)
          .toList();
      await cacheService.saveExpenses(
        expense.cohortId,
        [savedExpense, ...updatedExpenses],
      );

      return savedExpense;
    } catch (_) {
      return effectiveExpense;
    }
  }

  /// Updates an existing expense and refreshes its splits
  Future<Expense> updateExpense(Expense expense) async {
    // Update local cache
    final currentExpenses = cacheService.getCachedExpenses(expense.cohortId);
    final updatedList = currentExpenses.map((e) {
      return e.id == expense.id ? expense : e;
    }).toList();
    await cacheService.saveExpenses(expense.cohortId, updatedList);

    if (!supabaseService.isConfigured || !isUuid(expense.id)) {
      return expense;
    }

    try {
      final updatePayload = <String, dynamic>{
        'title': expense.title,
        'category': expense.category,
        'custom_icon': expense.customIcon,
        'total_amount': expense.totalAmount,
        'paid_by_user_id': expense.paidByUserId,
        'split_type': expense.splitType.toDbString(),
        'receipt_url': expense.receiptUrl,
        'notes': expense.notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final expRow = await supabaseService.client
          .from('expenses')
          .update(updatePayload)
          .eq('id', expense.id)
          .select()
          .single();

      // Refresh splits: delete and re-insert
      await supabaseService.client
          .from('expense_splits')
          .delete()
          .eq('expense_id', expense.id);

      if (expense.splits.isNotEmpty) {
        final splitPayloads = expense.splits
            .where((s) => isUuid(s.userId))
            .map((s) => {
                  'expense_id': expense.id,
                  'user_id': s.userId,
                  'amount': s.amount,
                  if (s.percentage != null) 'percentage': s.percentage,
                })
            .toList();

        if (splitPayloads.isNotEmpty) {
          await supabaseService.client
              .from('expense_splits')
              .insert(splitPayloads);
        }
      }

      final saved = Expense.fromJson({
        ...expRow,
        'splits': expense.splits.map((s) => s.toJson()).toList(),
      });
      return saved;
    } catch (_) {
      return expense;
    }
  }

  /// Deletes an expense from Supabase & local cache
  Future<void> deleteExpense(String expenseId, String cohortId) async {
    final currentExpenses = cacheService.getCachedExpenses(cohortId);
    final updated = currentExpenses.where((e) => e.id != expenseId).toList();
    await cacheService.saveExpenses(cohortId, updated);

    if (!supabaseService.isConfigured || !isUuid(expenseId)) return;

    try {
      await supabaseService.client
          .from('expenses')
          .delete()
          .eq('id', expenseId);
    } catch (_) {}
  }

  // --- Comments ---

  Future<List<TransactionComment>> fetchCommentsForExpense(String expenseId) async {
    if (!supabaseService.isConfigured || !isUuid(expenseId)) {
      return cacheService.getCachedComments(expenseId);
    }

    try {
      final rows = await supabaseService.client
          .from('comments')
          .select('*, profiles:user_id(*)')
          .eq('expense_id', expenseId)
          .order('created_at', ascending: true);

      final comments = (rows as List)
          .map((r) => TransactionComment.fromJson(r as Map<String, dynamic>))
          .toList();

      await cacheService.saveComments(expenseId, comments);
      return comments;
    } catch (_) {
      return cacheService.getCachedComments(expenseId);
    }
  }

  Future<TransactionComment> addComment(TransactionComment comment) async {
    String userId = comment.userId;
    UserProfile? profile = comment.profile;

    if (!isUuid(userId)) {
      profile = await profileRepository.getCurrentProfile();
      userId = profile.id;
    }

    final effectiveComment = comment.copyWith(userId: userId, profile: profile);

    if (comment.expenseId != null) {
      final cached = cacheService.getCachedComments(comment.expenseId!);
      await cacheService.saveComments(comment.expenseId!, [...cached, effectiveComment]);
    }

    if (!supabaseService.isConfigured ||
        (comment.expenseId != null && !isUuid(comment.expenseId!))) {
      return effectiveComment;
    }

    try {
      final insertData = <String, dynamic>{
        if (isUuid(comment.id)) 'id': comment.id,
        if (comment.expenseId != null) 'expense_id': comment.expenseId,
        if (comment.cohortId != null) 'cohort_id': comment.cohortId,
        'user_id': userId,
        'content': comment.content,
      };

      final row = await supabaseService.client
          .from('comments')
          .insert(insertData)
          .select('*, profiles:user_id(*)')
          .single();

      final saved = TransactionComment.fromJson(row);

      if (comment.expenseId != null) {
        final cached = cacheService.getCachedComments(comment.expenseId!);
        final updated = cached.where((c) => c.id != comment.id).toList();
        await cacheService.saveComments(comment.expenseId!, [...updated, saved]);
      }

      return saved;
    } catch (_) {
      return effectiveComment;
    }
  }

  // --- Shortcuts ---

  Future<List<ExpenseShortcut>> fetchShortcuts(String cohortId) async {
    if (!supabaseService.isConfigured || !isUuid(cohortId)) {
      return cacheService.getCachedShortcuts(cohortId);
    }

    try {
      final rows = await supabaseService.client
          .from('expense_shortcuts')
          .select('*')
          .eq('cohort_id', cohortId)
          .order('created_at', ascending: true);

      final shortcuts = (rows as List)
          .map((r) => ExpenseShortcut.fromJson(r as Map<String, dynamic>))
          .toList();

      await cacheService.saveShortcuts(cohortId, shortcuts);
      return shortcuts;
    } catch (_) {
      return cacheService.getCachedShortcuts(cohortId);
    }
  }

  Future<ExpenseShortcut> createShortcut(ExpenseShortcut shortcut) async {
    final currentShortcuts = cacheService.getCachedShortcuts(shortcut.cohortId);
    await cacheService.saveShortcuts(shortcut.cohortId, [...currentShortcuts, shortcut]);

    if (!supabaseService.isConfigured || !isUuid(shortcut.cohortId)) {
      return shortcut;
    }

    try {
      final row = await supabaseService.client
          .from('expense_shortcuts')
          .insert(shortcut.toJson())
          .select()
          .single();

      final saved = ExpenseShortcut.fromJson(row);
      final updated = currentShortcuts.where((s) => s.id != shortcut.id).toList();
      await cacheService.saveShortcuts(shortcut.cohortId, [...updated, saved]);
      return saved;
    } catch (_) {
      return shortcut;
    }
  }

  Future<void> deleteShortcut(String shortcutId, String cohortId) async {
    final currentShortcuts = cacheService.getCachedShortcuts(cohortId);
    final updated = currentShortcuts.where((s) => s.id != shortcutId).toList();
    await cacheService.saveShortcuts(cohortId, updated);

    if (!supabaseService.isConfigured || !isUuid(shortcutId)) return;

    try {
      await supabaseService.client
          .from('expense_shortcuts')
          .delete()
          .eq('id', shortcutId);
    } catch (_) {}
  }
}

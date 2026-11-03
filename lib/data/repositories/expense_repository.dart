import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
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
    if (!supabaseService.isConfigured ||
        !isUuid(cohortId) ||
        cohortId.startsWith('local_')) {
      return cacheService
          .getCachedExpenses(cohortId)
          .where((e) => !e.isDeleted)
          .toList();
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
      return expenses.where((e) => !e.isDeleted).toList();
    } catch (_) {
      return cacheService.getCachedExpenses(cohortId).where((e) => !e.isDeleted).toList();
    }
  }

  /// Fetches all expenses and their associated splits for a specific friendship (1-on-1)
  Future<List<Expense>> fetchExpensesForFriend(String friendshipId) async {
    if (!supabaseService.isConfigured ||
        !isUuid(friendshipId) ||
        friendshipId.startsWith('local_')) {
      return cacheService
          .getCachedFriendExpenses(friendshipId)
          .where((e) => !e.isDeleted)
          .toList();
    }

    try {
      final expenseRows = await supabaseService.client
          .from('expenses')
          .select('*')
          .eq('friendship_id', friendshipId)
          .order('created_at', ascending: false);

      final rows = (expenseRows as List);
      if (rows.isEmpty) {
        await cacheService.saveFriendExpenses(friendshipId, []);
        return [];
      }

      final expenseIds = rows
          .map((r) => r['id'] as String?)
          .whereType<String>()
          .toList();

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

      await cacheService.saveFriendExpenses(friendshipId, expenses);
      return expenses.where((e) => !e.isDeleted).toList();
    } catch (_) {
      return cacheService
          .getCachedFriendExpenses(friendshipId)
          .where((e) => !e.isDeleted)
          .toList();
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
    final is1on1 = effectiveExpense.is1on1;
    final destId = effectiveExpense.destinationId;

    // Optimistically update local cache
    final currentExpenses = is1on1
        ? cacheService.getCachedFriendExpenses(destId)
        : cacheService.getCachedExpenses(destId);

    if (is1on1) {
      await cacheService.saveFriendExpenses(
        destId,
        [effectiveExpense, ...currentExpenses],
      );
    } else {
      await cacheService.saveExpenses(
        destId,
        [effectiveExpense, ...currentExpenses],
      );
    }

    if (!supabaseService.isConfigured ||
        !isUuid(destId) ||
        destId.startsWith('local_')) {
      return effectiveExpense;
    }

    try {
      String? notesPayload = expense.notes;
      if (expense.payers.length > 1) {
        final payersJson = jsonEncode(expense.payers.map((p) => p.toJson()).toList());
        final tag = '[FS_PAYERS: $payersJson]';
        notesPayload = (notesPayload == null || notesPayload.isEmpty)
            ? tag
            : '$notesPayload\n$tag';
      }

      final insertPayload = <String, dynamic>{
        if (isUuid(expense.id)) 'id': expense.id,
        if (!is1on1) 'cohort_id': expense.cohortId,
        if (is1on1) 'friendship_id': expense.friendshipId,
        'title': expense.title,
        'category': expense.category,
        'custom_icon': expense.customIcon,
        'total_amount': expense.totalAmount,
        'currency': expense.currency,
        'paid_by_user_id': paidByUserId,
        'split_type': expense.splitType.toDbString(),
        'receipt_url': expense.receiptUrl,
        'notes': notesPayload,
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
        'payers': expense.payers.map((p) => p.toJson()).toList(),
      });

      // Update cache with server-saved record
      final updatedExpenses = currentExpenses
          .where((e) => e.id != expense.id && e.id != savedExpense.id)
          .toList();

      if (is1on1) {
        await cacheService.saveFriendExpenses(
          destId,
          [savedExpense, ...updatedExpenses],
        );
      } else {
        await cacheService.saveExpenses(
          destId,
          [savedExpense, ...updatedExpenses],
        );
      }

      return savedExpense;
    } catch (_) {
      return effectiveExpense;
    }
  }

  /// Batch creates expenses (e.g. from CSV import) directly into Supabase and local cache
  Future<List<Expense>> batchCreateExpenses(String cohortId, List<Expense> expenses) async {
    if (expenses.isEmpty) return [];

    // 1. Optimistically update local cache
    final existingExpenses = cacheService.getCachedExpenses(cohortId);
    final combinedExpenses = [...existingExpenses, ...expenses];
    await cacheService.saveExpenses(cohortId, combinedExpenses);

    // 2. If Supabase is unconfigured or not a UUID, return cached
    if (!supabaseService.isConfigured || !isUuid(cohortId) || cohortId.startsWith('local_')) {
      return expenses;
    }

    try {
      final List<Map<String, dynamic>> expensePayloads = [];
      final List<Map<String, dynamic>> splitPayloads = [];

      for (final exp in expenses) {
        String paidByUserId = exp.paidByUserId;
        if (!isUuid(paidByUserId)) {
          final profile = await profileRepository.getCurrentProfile();
          paidByUserId = profile.id;
        }

        String? notesPayload = exp.notes;
        if (exp.payers.length > 1) {
          final payersJson = jsonEncode(exp.payers.map((p) => p.toJson()).toList());
          final tag = '[FS_PAYERS: $payersJson]';
          notesPayload = (notesPayload == null || notesPayload.isEmpty)
              ? tag
              : '$notesPayload\n$tag';
        }

        final expId = isUuid(exp.id) ? exp.id : const Uuid().v4();

        expensePayloads.add({
          'id': expId,
          'cohort_id': cohortId,
          'title': exp.title,
          'category': exp.category,
          'custom_icon': exp.customIcon,
          'total_amount': exp.totalAmount,
          'currency': exp.currency,
          'paid_by_user_id': paidByUserId,
          'split_type': exp.splitType.toDbString(),
          'receipt_url': exp.receiptUrl,
          'notes': notesPayload,
          'created_at': exp.createdAt.toIso8601String(),
        });

        for (final split in exp.splits) {
          if (isUuid(split.userId)) {
            splitPayloads.add({
              'expense_id': expId,
              'user_id': split.userId,
              'amount': split.amount,
              if (split.percentage != null) 'percentage': split.percentage,
            });
          }
        }
      }

      // Batch insert into public.expenses in chunks of 50
      const chunkSize = 50;
      for (int i = 0; i < expensePayloads.length; i += chunkSize) {
        final chunk = expensePayloads.sublist(
          i,
          (i + chunkSize) > expensePayloads.length ? expensePayloads.length : i + chunkSize,
        );
        await supabaseService.client.from('expenses').insert(chunk);
      }

      // Batch insert into public.expense_splits in chunks
      for (int i = 0; i < splitPayloads.length; i += chunkSize) {
        final chunk = splitPayloads.sublist(
          i,
          (i + chunkSize) > splitPayloads.length ? splitPayloads.length : i + chunkSize,
        );
        await supabaseService.client.from('expense_splits').insert(chunk);
      }

      return expenses;
    } catch (e, st) {
      debugPrint('[ExpenseRepository] batchCreateExpenses error: $e\n$st');
      return expenses;
    }
  }

  /// Updates an existing expense and refreshes its splits
  Future<Expense> updateExpense(Expense expense) async {
    final is1on1 = expense.is1on1;
    final destId = expense.destinationId;

    // Update local cache
    final currentExpenses = is1on1
        ? cacheService.getCachedFriendExpenses(destId)
        : cacheService.getCachedExpenses(destId);
    final updatedList = currentExpenses.map((e) {
      return e.id == expense.id ? expense : e;
    }).toList();

    if (is1on1) {
      await cacheService.saveFriendExpenses(destId, updatedList);
    } else {
      await cacheService.saveExpenses(destId, updatedList);
    }

    if (!supabaseService.isConfigured || !isUuid(expense.id)) {
      return expense;
    }

    try {
      String? notesPayload = expense.notes;
      if (expense.payers.length > 1) {
        final payersJson = jsonEncode(expense.payers.map((p) => p.toJson()).toList());
        final tag = '[FS_PAYERS: $payersJson]';
        notesPayload = (notesPayload == null || notesPayload.isEmpty)
            ? tag
            : '$notesPayload\n$tag';
      }

      final updatePayload = <String, dynamic>{
        'title': expense.title,
        'category': expense.category,
        'custom_icon': expense.customIcon,
        'total_amount': expense.totalAmount,
        'paid_by_user_id': expense.paidByUserId,
        'split_type': expense.splitType.toDbString(),
        'receipt_url': expense.receiptUrl,
        'notes': notesPayload,
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
        'payers': expense.payers.map((p) => p.toJson()).toList(),
      });
      return saved;
    } catch (_) {
      return expense;
    }
  }

  /// Soft deletes an expense (moves to trash for 24-hour recovery)
  Future<void> deleteExpense(String expenseId, String cohortId) async {
    final now = DateTime.now();
    final currentExpenses = cacheService.getCachedExpenses(cohortId);
    Expense? targetExpense;
    final updated = currentExpenses.map((e) {
      if (e.id == expenseId) {
        targetExpense = e.copyWith(isDeleted: true, deletedAt: now);
        return targetExpense!;
      }
      return e;
    }).toList();
    await cacheService.saveExpenses(cohortId, updated);

    if (!supabaseService.isConfigured || !isUuid(expenseId)) return;

    try {
      String? updatedNotes = targetExpense?.notes;
      final delTag = '[FS_DELETED: ${jsonEncode({'deleted_at': now.toIso8601String()})}]';
      updatedNotes = (updatedNotes == null || updatedNotes.isEmpty)
          ? delTag
          : '$updatedNotes\n$delTag';

      await supabaseService.client
          .from('expenses')
          .update({
            'notes': updatedNotes,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', expenseId);
    } catch (_) {}
  }

  /// Soft deletes a 1-on-1 friend expense
  Future<void> deleteFriendExpense(String expenseId, String friendshipId) async {
    final now = DateTime.now();
    final currentExpenses = cacheService.getCachedFriendExpenses(friendshipId);
    Expense? targetExpense;
    final updated = currentExpenses.map((e) {
      if (e.id == expenseId) {
        targetExpense = e.copyWith(isDeleted: true, deletedAt: now);
        return targetExpense!;
      }
      return e;
    }).toList();
    await cacheService.saveFriendExpenses(friendshipId, updated);

    if (!supabaseService.isConfigured || !isUuid(expenseId)) return;

    try {
      String? updatedNotes = targetExpense?.notes;
      final delTag = '[FS_DELETED: ${jsonEncode({'deleted_at': now.toIso8601String()})}]';
      updatedNotes = (updatedNotes == null || updatedNotes.isEmpty)
          ? delTag
          : '$updatedNotes\n$delTag';

      await supabaseService.client
          .from('expenses')
          .update({
            'notes': updatedNotes,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', expenseId);
    } catch (_) {}
  }

  /// Restores a soft-deleted expense back to the active ledger
  Future<Expense?> restoreExpense(String expenseId, String cohortId) async {
    final currentExpenses = cacheService.getCachedExpenses(cohortId);
    Expense? restored;
    final updated = currentExpenses.map((e) {
      if (e.id == expenseId) {
        restored = e.copyWith(isDeleted: false, clearDeletedAt: true);
        return restored!;
      }
      return e;
    }).toList();
    await cacheService.saveExpenses(cohortId, updated);

    if (restored == null) return null;

    if (!supabaseService.isConfigured || !isUuid(expenseId)) return restored;

    try {
      String? cleanNotes = restored?.notes;
      if (cleanNotes != null && cleanNotes.contains('[FS_DELETED:')) {
        cleanNotes = cleanNotes.replaceAll(RegExp(r'\[FS_DELETED:\s*.*?\]', dotAll: true), '').trim();
        if (cleanNotes.isEmpty) cleanNotes = null;
      }

      await supabaseService.client
          .from('expenses')
          .update({
            'notes': cleanNotes,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', expenseId);
    } catch (_) {}

    return restored;
  }

  /// Permanently purges an expense from Supabase and local cache
  Future<void> purgeExpensePermanently(String expenseId, String cohortId) async {
    final currentExpenses = cacheService.getCachedExpenses(cohortId);
    final updated = currentExpenses.where((e) => e.id != expenseId).toList();
    await cacheService.saveExpenses(cohortId, updated);

    if (!supabaseService.isConfigured || !isUuid(expenseId)) return;

    try {
      await supabaseService.client
          .from('expense_splits')
          .delete()
          .eq('expense_id', expenseId);
      await supabaseService.client
          .from('expenses')
          .delete()
          .eq('id', expenseId);
    } catch (_) {}
  }

  /// Automatically purges expenses that have been in trash for > 24 hours
  Future<List<String>> purgeExpiredDeletedExpenses(String cohortId) async {
    final currentExpenses = cacheService.getCachedExpenses(cohortId);
    final now = DateTime.now();
    const twentyFourHours = Duration(hours: 24);
    final expiredIds = <String>[];

    for (final e in currentExpenses) {
      if (e.isDeleted && e.deletedAt != null) {
        if (now.difference(e.deletedAt!) >= twentyFourHours) {
          expiredIds.add(e.id);
          await purgeExpensePermanently(e.id, cohortId);
        }
      }
    }

    return expiredIds;
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

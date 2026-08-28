import { supabase, isSupabaseConfigured } from './client';
import { Expense, ExpenseSplit, TransactionComment } from '@/types';
import { DEFAULT_EXPENSES } from './placeholderData';

/**
 * Maps Supabase raw expense record and splits into Expense domain model
 */
function mapExpenseRow(row: any, splits: any[] = []): Expense {
  const mappedSplits: ExpenseSplit[] = (splits || []).map((s: any) => ({
    userId: s.user_id,
    amount: Number(s.amount),
    percentage: s.percentage !== null && s.percentage !== undefined ? Number(s.percentage) : undefined,
  }));

  return {
    id: row.id,
    cohortId: row.cohort_id,
    title: row.title,
    category: row.category || 'General',
    customIcon: row.custom_icon,
    totalAmount: Number(row.total_amount),
    currency: row.currency || 'INR',
    paidByUserId: row.paid_by_user_id,
    splitType: row.split_type || 'equal',
    splits: mappedSplits,
    receiptUrl: row.receipt_url,
    ocrParsed: row.ocr_parsed ?? false,
    notes: row.notes,
    createdAt: row.created_at || new Date().toISOString(),
    updatedAt: row.updated_at || new Date().toISOString(),
  };
}

/**
 * Fetches all expenses and their associated splits for a specific cohort
 */
export async function fetchExpensesForCohort(cohortId: string): Promise<Expense[]> {
  if (!isSupabaseConfigured()) {
    return DEFAULT_EXPENSES[cohortId] || [];
  }

  try {
    const { data: expenseRows, error: expErr } = await supabase
      .from('expenses')
      .select('*')
      .eq('cohort_id', cohortId)
      .order('created_at', { ascending: false });

    if (expErr) throw expErr;
    if (!expenseRows || expenseRows.length === 0) {
      return [];
    }

    const expenseIds = expenseRows.map((e: any) => e.id);

    // Fetch splits for these expenses
    const { data: splitRows, error: splitErr } = await supabase
      .from('expense_splits')
      .select('*')
      .in('expense_id', expenseIds);

    if (splitErr) throw splitErr;

    const splitsByExpense: Record<string, any[]> = {};
    (splitRows || []).forEach((s: any) => {
      if (!splitsByExpense[s.expense_id]) {
        splitsByExpense[s.expense_id] = [];
      }
      splitsByExpense[s.expense_id].push(s);
    });

    return expenseRows.map((e: any) => mapExpenseRow(e, splitsByExpense[e.id] || []));
  } catch (err) {
    console.warn(`[ExpenseService] fetchExpensesForCohort fallback for ${cohortId}:`, err);
    return DEFAULT_EXPENSES[cohortId] || [];
  }
}

/**
 * Creates a new expense and its split allocations in Supabase
 */
export async function createExpense(expense: Expense): Promise<Expense> {
  if (!isSupabaseConfigured()) {
    return expense;
  }

  try {
    const { data: expRow, error: expErr } = await supabase
      .from('expenses')
      .insert({
        id: expense.id.startsWith('exp_') ? undefined : expense.id,
        cohort_id: expense.cohortId,
        title: expense.title,
        category: expense.category,
        total_amount: expense.totalAmount,
        currency: expense.currency || 'INR',
        paid_by_user_id: expense.paidByUserId,
        split_type: expense.splitType,
        receipt_url: expense.receiptUrl,
        notes: expense.notes,
      })
      .select()
      .single();

    if (expErr) throw expErr;

    const savedExpenseId = expRow.id;

    // Insert splits
    if (expense.splits && expense.splits.length > 0) {
      const splitPayloads = expense.splits.map((s) => ({
        expense_id: savedExpenseId,
        user_id: s.userId,
        amount: s.amount,
        percentage: s.percentage ?? null,
      }));

      const { error: splitErr } = await supabase
        .from('expense_splits')
        .insert(splitPayloads);

      if (splitErr) console.warn('[ExpenseService] Insert splits warning:', splitErr);
    }

    return mapExpenseRow(expRow, expense.splits.map(s => ({ user_id: s.userId, amount: s.amount, percentage: s.percentage })));
  } catch (err) {
    console.warn('[ExpenseService] createExpense fallback:', err);
    return expense;
  }
}

/**
 * Updates an existing expense and updates split allocations
 */
export async function updateExpense(expense: Expense): Promise<Expense> {
  if (!isSupabaseConfigured()) {
    return expense;
  }

  try {
    const { data: expRow, error: expErr } = await supabase
      .from('expenses')
      .update({
        title: expense.title,
        category: expense.category,
        total_amount: expense.totalAmount,
        paid_by_user_id: expense.paidByUserId,
        split_type: expense.splitType,
        receipt_url: expense.receiptUrl,
        notes: expense.notes,
        updated_at: new Date().toISOString(),
      })
      .eq('id', expense.id)
      .select()
      .single();

    if (expErr) throw expErr;

    // Refresh splits: delete and re-insert
    await supabase.from('expense_splits').delete().eq('expense_id', expense.id);

    if (expense.splits && expense.splits.length > 0) {
      const splitPayloads = expense.splits.map((s) => ({
        expense_id: expense.id,
        user_id: s.userId,
        amount: s.amount,
        percentage: s.percentage ?? null,
      }));

      await supabase.from('expense_splits').insert(splitPayloads);
    }

    return mapExpenseRow(expRow, expense.splits.map(s => ({ user_id: s.userId, amount: s.amount, percentage: s.percentage })));
  } catch (err) {
    console.warn(`[ExpenseService] updateExpense fallback for ${expense.id}:`, err);
    return expense;
  }
}

/**
 * Deletes an expense from Supabase
 */
export async function deleteExpense(expenseId: string): Promise<void> {
  if (!isSupabaseConfigured()) return;

  try {
    const { error } = await supabase
      .from('expenses')
      .delete()
      .eq('id', expenseId);

    if (error) throw error;
  } catch (err) {
    console.warn(`[ExpenseService] deleteExpense fallback for ${expenseId}:`, err);
  }
}

/**
 * Fetches transaction comments for an expense
 */
export async function fetchCommentsForExpense(expenseId: string): Promise<TransactionComment[]> {
  if (!isSupabaseConfigured()) return [];

  try {
    const { data, error } = await supabase
      .from('transaction_comments')
      .select('*, profiles:user_id(*)')
      .eq('expense_id', expenseId)
      .order('created_at', { ascending: true });

    if (error) throw error;

    return (data || []).map((row: any) => ({
      id: row.id,
      expenseId: row.expense_id,
      userId: row.user_id,
      content: row.content,
      createdAt: row.created_at || new Date().toISOString(),
      profile: row.profiles
        ? {
            id: row.profiles.id,
            fullName: row.profiles.full_name,
            avatarUrl: row.profiles.avatar_url,
            email: row.profiles.email,
            vpaId: row.profiles.vpa_id,
            isGuest: row.profiles.is_guest ?? false,
            createdAt: row.profiles.created_at,
          }
        : undefined,
    }));
  } catch (err) {
    console.warn(`[ExpenseService] fetchCommentsForExpense fallback for ${expenseId}:`, err);
    return [];
  }
}

/**
 * Adds a new comment to an expense
 */
export async function addComment(comment: TransactionComment): Promise<TransactionComment> {
  if (!isSupabaseConfigured()) {
    return comment;
  }

  try {
    const { data, error } = await supabase
      .from('transaction_comments')
      .insert({
        id: comment.id.startsWith('cmt_') ? undefined : comment.id,
        expense_id: comment.expenseId,
        user_id: comment.userId,
        content: comment.content,
      })
      .select('*, profiles:user_id(*)')
      .single();

    if (error) throw error;

    return {
      id: data.id,
      expenseId: data.expense_id,
      userId: data.user_id,
      content: data.content,
      createdAt: data.created_at,
      profile: data.profiles
        ? {
            id: data.profiles.id,
            fullName: data.profiles.full_name,
            avatarUrl: data.profiles.avatar_url,
            email: data.profiles.email,
            vpaId: data.profiles.vpa_id,
            isGuest: data.profiles.is_guest ?? false,
            createdAt: data.profiles.created_at,
          }
        : comment.profile,
    };
  } catch (err) {
    console.warn('[ExpenseService] addComment fallback:', err);
    return comment;
  }
}

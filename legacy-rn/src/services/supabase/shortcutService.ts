import { supabase, isSupabaseConfigured } from './client';
import { ExpenseShortcut } from '@/types';
import { DEFAULT_SHORTCUTS } from './placeholderData';
import { isUuid, getCurrentProfile } from './profileService';

/**
 * Service managing Supabase sync for Group-Scoped Expense Shortcuts
 */

export async function fetchShortcuts(cohortId: string): Promise<ExpenseShortcut[]> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) {
    return DEFAULT_SHORTCUTS[cohortId] || [];
  }

  try {
    const { data, error } = await supabase
      .from('expense_shortcuts')
      .select('*')
      .eq('cohort_id', cohortId)
      .order('created_at', { ascending: true });

    if (error) throw error;

    return (data || []).map((row: any) => ({
      id: row.id,
      cohortId: row.cohort_id,
      title: row.title,
      category: row.category || 'general',
      customIcon: row.custom_icon,
      amount: Number(row.amount),
      paidByUserId: row.paid_by_user_id,
      splitType: row.split_type || 'equal',
      isMultiplePayers: row.split_payload?.isMultiplePayers,
      paidAmounts: row.split_payload?.paidAmounts,
      splits: row.split_payload?.splits,
      includedMemberIds: row.split_payload?.includedMemberIds,
      exactSplits: row.split_payload?.exactSplits,
      percentageSplits: row.split_payload?.percentageSplits,
      sharesSplits: row.split_payload?.sharesSplits,
      adjustmentSplits: row.split_payload?.adjustmentSplits,
      createdAt: row.created_at || new Date().toISOString(),
    }));
  } catch (err) {
    console.warn(`[ShortcutService] fetchShortcuts fallback for ${cohortId}:`, err);
    return DEFAULT_SHORTCUTS[cohortId] || [];
  }
}

export async function createShortcut(shortcut: ExpenseShortcut): Promise<ExpenseShortcut> {
  if (!isSupabaseConfigured() || !isUuid(shortcut.cohortId)) {
    return shortcut;
  }

  let paidByUserId = shortcut.paidByUserId;
  if (paidByUserId && !isUuid(paidByUserId)) {
    const profile = await getCurrentProfile();
    paidByUserId = profile.id;
  }

  try {
    const splitPayload = {
      isMultiplePayers: shortcut.isMultiplePayers,
      paidAmounts: shortcut.paidAmounts,
      splits: shortcut.splits,
      includedMemberIds: shortcut.includedMemberIds?.filter(isUuid),
      exactSplits: shortcut.exactSplits,
      percentageSplits: shortcut.percentageSplits,
      sharesSplits: shortcut.sharesSplits,
      adjustmentSplits: shortcut.adjustmentSplits,
    };

    const { data, error } = await supabase
      .from('expense_shortcuts')
      .insert({
        id: isUuid(shortcut.id) ? shortcut.id : undefined,
        cohort_id: shortcut.cohortId,
        title: shortcut.title,
        category: shortcut.category,
        custom_icon: shortcut.customIcon,
        amount: shortcut.amount,
        paid_by_user_id: paidByUserId || null,
        split_type: shortcut.splitType,
        split_payload: splitPayload,
      })
      .select()
      .single();

    if (error) throw error;

    return {
      ...shortcut,
      id: data.id,
      createdAt: data.created_at,
    };
  } catch (err) {
    console.warn('[ShortcutService] createShortcut fallback:', err);
    return shortcut;
  }
}

export async function deleteShortcut(shortcutId: string): Promise<void> {
  if (!isSupabaseConfigured() || !isUuid(shortcutId)) return;

  try {
    const { error } = await supabase
      .from('expense_shortcuts')
      .delete()
      .eq('id', shortcutId);

    if (error) throw error;
  } catch (err) {
    console.warn(`[ShortcutService] deleteShortcut fallback for ${shortcutId}:`, err);
  }
}

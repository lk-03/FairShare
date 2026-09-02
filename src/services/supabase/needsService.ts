import { supabase, isSupabaseConfigured } from './client';
import { SharedListItem } from '@/types';
import { DEFAULT_SHARED_LISTS } from './placeholderData';
import { isUuid, getCurrentProfile } from './profileService';

/**
 * Service managing Supabase sync for Shared List Items (House Cart / Needs)
 */

export async function fetchSharedListItems(cohortId: string): Promise<SharedListItem[]> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) {
    return DEFAULT_SHARED_LISTS[cohortId] || [];
  }

  try {
    const { data, error } = await supabase
      .from('shared_list_items')
      .select('*')
      .eq('cohort_id', cohortId)
      .order('created_at', { ascending: false });

    if (error) throw error;

    return (data || []).map((row: any) => ({
      id: row.id,
      cohortId: row.cohort_id,
      title: row.title,
      addedByUserId: row.added_by_user_id,
      isCompleted: row.is_completed ?? false,
      completedAt: row.completed_at,
      createdAt: row.created_at || new Date().toISOString(),
    }));
  } catch (err) {
    console.warn(`[NeedsService] fetchSharedListItems fallback for ${cohortId}:`, err);
    return DEFAULT_SHARED_LISTS[cohortId] || [];
  }
}

export async function createSharedListItem(item: SharedListItem): Promise<SharedListItem> {
  if (!isSupabaseConfigured() || !isUuid(item.cohortId)) {
    return item;
  }

  let addedByUserId = item.addedByUserId;
  if (!isUuid(addedByUserId)) {
    const profile = await getCurrentProfile();
    addedByUserId = profile.id;
  }

  try {
    const { data, error } = await supabase
      .from('shared_list_items')
      .insert({
        id: isUuid(item.id) ? item.id : undefined,
        cohort_id: item.cohortId,
        title: item.title,
        added_by_user_id: addedByUserId,
        is_completed: item.isCompleted,
        completed_at: item.completedAt,
      })
      .select()
      .single();

    if (error) throw error;

    return {
      id: data.id,
      cohortId: data.cohort_id,
      title: data.title,
      addedByUserId: data.added_by_user_id,
      isCompleted: data.is_completed,
      completedAt: data.completed_at,
      createdAt: data.created_at,
    };
  } catch (err) {
    console.warn('[NeedsService] createSharedListItem fallback:', err);
    return item;
  }
}

export async function toggleSharedListItem(
  itemId: string,
  isCompleted: boolean
): Promise<void> {
  if (!isSupabaseConfigured() || !isUuid(itemId)) return;

  try {
    const { error } = await supabase
      .from('shared_list_items')
      .update({
        is_completed: isCompleted,
        completed_at: isCompleted ? new Date().toISOString() : null,
      })
      .eq('id', itemId);

    if (error) throw error;
  } catch (err) {
    console.warn(`[NeedsService] toggleSharedListItem fallback for ${itemId}:`, err);
  }
}

export async function deleteSharedListItem(itemId: string): Promise<void> {
  if (!isSupabaseConfigured() || !isUuid(itemId)) return;

  try {
    const { error } = await supabase
      .from('shared_list_items')
      .delete()
      .eq('id', itemId);

    if (error) throw error;
  } catch (err) {
    console.warn(`[NeedsService] deleteSharedListItem fallback for ${itemId}:`, err);
  }
}

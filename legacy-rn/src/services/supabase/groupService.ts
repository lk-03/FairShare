import { supabase, isSupabaseConfigured } from './client';
import { EventCohort, GroupMember, UserProfile } from '@/types';
import { DEFAULT_COHORTS, DEFAULT_MEMBERS } from './placeholderData';
import { isUuid, getCurrentProfile } from './profileService';

/**
 * Maps Supabase raw cohort record to EventCohort domain model
 */
function mapCohortRow(row: any): EventCohort {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    category: row.category,
    customIcon: row.custom_icon,
    bannerUrl: row.banner_url,
    avatarUrl: row.avatar_url || row.banner_url,
    currency: row.currency || 'INR',
    createdBy: row.created_by,
    inviteCode: row.invite_code,
    isArchived: row.is_archived ?? false,
    archivedAt: row.archived_at || undefined,
    isDeleted: row.is_deleted ?? false,
    deletedAt: row.deleted_at || undefined,
    createdAt: row.created_at || new Date().toISOString(),
    updatedAt: row.updated_at || new Date().toISOString(),
  };
}

/**
 * Maps Supabase raw group_member record to GroupMember domain model
 */
function mapMemberRow(row: any): GroupMember {
  let profile: UserProfile | undefined = undefined;
  if (row.profiles) {
    profile = {
      id: row.profiles.id,
      fullName: row.profiles.full_name,
      email: row.profiles.email,
      nickname: row.profiles.nickname,
      username: row.profiles.username,
      avatarUrl: row.profiles.avatar_url,
      vpaId: row.profiles.vpa_id,
      phoneNumber: row.profiles.phone_number,
      isGuest: row.profiles.is_guest ?? false,
      authProvider: row.profiles.auth_provider || 'email',
      createdAt: row.profiles.created_at || row.joined_at,
    };
  }

  return {
    id: row.id,
    cohortId: row.cohort_id,
    userId: row.user_id,
    role: row.role || 'member',
    isPlaceholder: row.is_placeholder ?? false,
    originalCsvName: row.original_csv_name,
    joinedAt: row.joined_at || new Date().toISOString(),
    profile,
  };
}

/**
 * Fetches all cohorts that the user belongs to, including their active members.
 */
export async function fetchUserCohorts(userId: string): Promise<{
  cohorts: EventCohort[];
  members: Record<string, GroupMember[]>;
}> {
  if (!isSupabaseConfigured() || !isUuid(userId)) {
    return {
      cohorts: DEFAULT_COHORTS,
      members: DEFAULT_MEMBERS,
    };
  }

  try {
    // 1. Get all cohort IDs the user is a member of
    const { data: memberRows, error: memberErr } = await supabase
      .from('group_members')
      .select('cohort_id')
      .eq('user_id', userId);

    if (memberErr) throw memberErr;

    const cohortIds = (memberRows || []).map((r: any) => r.cohort_id);
    if (cohortIds.length === 0) {
      return { cohorts: [], members: {} };
    }

    // 2. Fetch cohort details
    const { data: cohortData, error: cohortErr } = await supabase
      .from('cohorts')
      .select('*')
      .in('id', cohortIds)
      .order('created_at', { ascending: false });

    if (cohortErr) throw cohortErr;

    // 3. Fetch all members across these cohorts with user profiles
    const { data: allMembers, error: allMembersErr } = await supabase
      .from('group_members')
      .select('*, profiles:user_id(*)')
      .in('cohort_id', cohortIds);

    if (allMembersErr) throw allMembersErr;

    const cohorts: EventCohort[] = (cohortData || []).map(mapCohortRow);
    const members: Record<string, GroupMember[]> = {};

    cohorts.forEach((c) => {
      members[c.id] = [];
    });

    (allMembers || []).forEach((m: any) => {
      const mapped = mapMemberRow(m);
      if (members[mapped.cohortId]) {
        members[mapped.cohortId].push(mapped);
      }
    });

    return { cohorts, members };
  } catch (err) {
    console.warn('[GroupService] fetchUserCohorts fallback:', err);
    return {
      cohorts: DEFAULT_COHORTS,
      members: DEFAULT_MEMBERS,
    };
  }
}

/**
 * Creates a new event cohort in Supabase and inserts creator as admin
 */
export async function createCohort(
  cohort: EventCohort,
  creator: UserProfile
): Promise<{ cohort: EventCohort; member: GroupMember }> {
  let effectiveCreator = creator;
  if (!isUuid(effectiveCreator.id)) {
    effectiveCreator = await getCurrentProfile();
  }

  const fallbackMember: GroupMember = {
    id: `m_${Date.now()}`,
    cohortId: cohort.id,
    userId: effectiveCreator.id,
    role: 'admin',
    joinedAt: new Date().toISOString(),
    profile: effectiveCreator,
  };

  if (!isSupabaseConfigured() || !isUuid(effectiveCreator.id)) {
    return { cohort, member: fallbackMember };
  }

  try {
    const { data: cohortRow, error: cohortErr } = await supabase
      .from('cohorts')
      .insert({
        id: isUuid(cohort.id) ? cohort.id : undefined,
        name: cohort.name,
        description: cohort.description,
        category: cohort.category,
        custom_icon: cohort.customIcon,
        avatar_url: cohort.avatarUrl || cohort.bannerUrl,
        banner_url: cohort.bannerUrl || cohort.avatarUrl,
        currency: cohort.currency || 'INR',
        invite_code: cohort.inviteCode,
        created_by: effectiveCreator.id,
      })
      .select()
      .single();

    if (cohortErr) throw cohortErr;

    const savedCohort = mapCohortRow(cohortRow);

    // Insert creator into group_members
    const { data: memberRow, error: memberErr } = await supabase
      .from('group_members')
      .insert({
        cohort_id: savedCohort.id,
        user_id: effectiveCreator.id,
        role: 'admin',
      })
      .select('*, profiles:user_id(*)')
      .single();

    if (memberErr) throw memberErr;

    const savedMember = mapMemberRow(memberRow);

    return { cohort: savedCohort, member: savedMember };
  } catch (err) {
    console.warn('[GroupService] createCohort fallback:', err);
    return { cohort, member: fallbackMember };
  }
}

/**
 * Updates cohort metadata
 */
export async function updateCohort(
  cohortId: string,
  updates: Partial<EventCohort>
): Promise<void> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) return;

  try {
    const dbPayload: any = {};
    if (updates.name !== undefined) dbPayload.name = updates.name;
    if (updates.description !== undefined) dbPayload.description = updates.description;
    if (updates.category !== undefined) dbPayload.category = updates.category;
    if (updates.customIcon !== undefined) dbPayload.custom_icon = updates.customIcon;
    if (updates.avatarUrl !== undefined || updates.bannerUrl !== undefined) {
      dbPayload.avatar_url = updates.avatarUrl || updates.bannerUrl;
      dbPayload.banner_url = updates.bannerUrl || updates.avatarUrl;
    }
    if (updates.currency !== undefined) dbPayload.currency = updates.currency;
    dbPayload.updated_at = new Date().toISOString();

    const { error } = await supabase
      .from('cohorts')
      .update(dbPayload)
      .eq('id', cohortId);

    if (error) throw error;
  } catch (err) {
    console.warn(`[GroupService] updateCohort fallback for ${cohortId}:`, err);
  }
}

/**
 * Joins a cohort by invite code
 */
export async function joinCohortByInviteCode(
  rawInviteCode: string,
  user: UserProfile
): Promise<{ cohort: EventCohort; member: GroupMember; members: GroupMember[] } | null> {
  const cleanCode = rawInviteCode
    .replace(/^(fairshare:\/\/join\/|https?:\/\/[^\/]+\/join\/)/i, '')
    .trim()
    .toUpperCase();

  let effectiveUser = user;
  if (!isUuid(effectiveUser.id)) {
    effectiveUser = await getCurrentProfile();
  }

  if (!isSupabaseConfigured() || !isUuid(effectiveUser.id)) {
    const found = DEFAULT_COHORTS.find(
      (c) => c.inviteCode.toUpperCase() === cleanCode
    );
    if (found) {
      const fallbackMember: GroupMember = {
        id: `m_${Date.now()}`,
        cohortId: found.id,
        userId: effectiveUser.id,
        role: 'member',
        joinedAt: new Date().toISOString(),
        profile: effectiveUser,
      };
      return { cohort: found, member: fallbackMember, members: [fallbackMember] };
    }
    return null;
  }

  try {
    // 1. Find cohort by invite_code or fallback by ID if UUID
    let query = supabase.from('cohorts').select('*').ilike('invite_code', cleanCode);
    let { data: cohortRow, error: cohortErr } = await query.maybeSingle();

    if (!cohortRow && isUuid(cleanCode)) {
      const idQuery = await supabase.from('cohorts').select('*').eq('id', cleanCode).maybeSingle();
      cohortRow = idQuery.data;
      cohortErr = idQuery.error;
    }

    if (cohortErr) throw cohortErr;
    if (!cohortRow) return null;

    const cohort = mapCohortRow(cohortRow);

    // 2. Ensure user profile is registered before foreign key insertion
    await supabase.from('profiles').upsert({
      id: effectiveUser.id,
      email: effectiveUser.email || undefined,
      full_name: effectiveUser.fullName || effectiveUser.nickname || 'You',
      avatar_url: effectiveUser.avatarUrl || undefined,
      nickname: effectiveUser.nickname || undefined,
      vpa_id: effectiveUser.vpaId || undefined,
      is_guest: false,
      auth_provider: effectiveUser.authProvider || 'email',
    });

    // 3. Join group_members if not already joined
    const { data: memberRow, error: memberErr } = await supabase
      .from('group_members')
      .upsert(
        {
          cohort_id: cohort.id,
          user_id: effectiveUser.id,
          role: 'member',
        },
        { onConflict: 'cohort_id,user_id' }
      )
      .select('*, profiles:user_id(*)')
      .single();

    if (memberErr) throw memberErr;

    const member = mapMemberRow(memberRow);

    // 4. Fetch all active members in this cohort so the joining user gets full roster
    const { data: allMembersData } = await supabase
      .from('group_members')
      .select('*, profiles:user_id(*)')
      .eq('cohort_id', cohort.id);

    const membersList = (allMembersData || []).map(mapMemberRow);

    return { cohort, member, members: membersList };
  } catch (err) {
    console.warn(`[GroupService] joinCohortByInviteCode error for ${cleanCode}:`, err);
    return null;
  }
}

/**
 * Inserts or syncs multiple members into a cohort (for CSV imports or invitations)
 */
export async function addMembersToCohort(
  cohortId: string,
  newMembers: GroupMember[]
): Promise<GroupMember[]> {
  if (!isSupabaseConfigured() || !isUuid(cohortId) || newMembers.length === 0) {
    return newMembers;
  }

  try {
    const payload = newMembers
      .filter((m) => isUuid(m.userId))
      .map((m) => ({
        cohort_id: cohortId,
        user_id: m.userId,
        role: m.role || 'member',
        is_placeholder: m.isPlaceholder ?? false,
        original_csv_name: m.originalCsvName,
      }));

    if (payload.length === 0) return newMembers;

    const { data, error } = await supabase
      .from('group_members')
      .upsert(payload, { onConflict: 'cohort_id,user_id' })
      .select('*, profiles:user_id(*)');

    if (error) throw error;
    return (data || []).map(mapMemberRow);
  } catch (err) {
    console.warn('[GroupService] addMembersToCohort fallback:', err);
    return newMembers;
  }
}

/**
 * Removes a member from a cohort in Supabase
 */
export async function removeMemberFromCohort(
  cohortId: string,
  userId: string
): Promise<boolean> {
  if (!isSupabaseConfigured() || !isUuid(cohortId) || !isUuid(userId)) return true;

  try {
    const { error } = await supabase
      .from('group_members')
      .delete()
      .eq('cohort_id', cohortId)
      .eq('user_id', userId);

    if (error) throw error;
    return true;
  } catch (err) {
    console.warn(`[GroupService] removeMemberFromCohort error for ${userId} in ${cohortId}:`, err);
    return false;
  }
}

/**
 * Updates a member's role in a cohort
 */
export async function updateMemberRole(
  cohortId: string,
  userId: string,
  role: 'admin' | 'member'
): Promise<boolean> {
  if (!isSupabaseConfigured() || !isUuid(cohortId) || !isUuid(userId)) return true;

  try {
    const { error } = await supabase
      .from('group_members')
      .update({ role })
      .eq('cohort_id', cohortId)
      .eq('user_id', userId);

    if (error) throw error;
    return true;
  } catch (err) {
    console.warn(`[GroupService] updateMemberRole error for ${userId} in ${cohortId}:`, err);
    return false;
  }
}

/**
 * Toggles archive status for a cohort (excluded from total owings, never auto-deleted)
 */
export async function toggleArchiveCohort(cohortId: string, isArchived: boolean): Promise<boolean> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) return true;

  try {
    const { error } = await supabase
      .from('cohorts')
      .update({
        is_archived: isArchived,
        archived_at: isArchived ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', cohortId);

    if (error) throw error;
    return true;
  } catch (err) {
    console.warn(`[GroupService] toggleArchiveCohort error for ${cohortId}:`, err);
    return false;
  }
}

/**
 * Soft deletes a cohort (moved to trash for 15 days recovery window)
 */
export async function deleteCohort(cohortId: string): Promise<boolean> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) return true;

  try {
    const { error } = await supabase
      .from('cohorts')
      .update({
        is_deleted: true,
        deleted_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', cohortId);

    if (error) throw error;
    return true;
  } catch (err) {
    console.warn(`[GroupService] deleteCohort error for ${cohortId}:`, err);
    return false;
  }
}

/**
 * Restores a deleted cohort back from trash
 */
export async function restoreDeletedCohort(cohortId: string): Promise<boolean> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) return true;

  try {
    const { error } = await supabase
      .from('cohorts')
      .update({
        is_deleted: false,
        deleted_at: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', cohortId);

    if (error) throw error;
    return true;
  } catch (err) {
    console.warn(`[GroupService] restoreDeletedCohort error for ${cohortId}:`, err);
    return false;
  }
}

/**
 * Permanently deletes a cohort and all its relational records from the database
 */
export async function deleteCohortPermanently(cohortId: string): Promise<boolean> {
  if (!isSupabaseConfigured() || !isUuid(cohortId)) return true;

  try {
    // Delete relational children first
    await supabase.from('expenses').delete().eq('cohort_id', cohortId);
    await supabase.from('shared_list_items').delete().eq('cohort_id', cohortId);
    await supabase.from('expense_shortcuts').delete().eq('cohort_id', cohortId);
    await supabase.from('group_members').delete().eq('cohort_id', cohortId);

    // Delete cohort
    const { error } = await supabase.from('cohorts').delete().eq('id', cohortId);
    if (error) throw error;
    return true;
  } catch (err) {
    console.warn(`[GroupService] deleteCohortPermanently error for ${cohortId}:`, err);
    return false;
  }
}

/**
 * Automatically purges cohorts that have been deleted/in trash for more than 15 days
 */
export async function purgeExpiredDeletedCohorts(cohorts: EventCohort[]): Promise<string[]> {
  const FIFTEEN_DAYS_MS = 15 * 24 * 60 * 60 * 1000;
  const now = Date.now();
  const expiredCohortIds: string[] = [];

  for (const c of cohorts) {
    if (c.isDeleted && c.deletedAt) {
      const deletedTime = new Date(c.deletedAt).getTime();
      if (now - deletedTime >= FIFTEEN_DAYS_MS) {
        expiredCohortIds.push(c.id);
        await deleteCohortPermanently(c.id);
      }
    }
  }

  return expiredCohortIds;
}

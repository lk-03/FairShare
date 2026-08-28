import { supabase, isSupabaseConfigured } from './client';
import { EventCohort, GroupMember, UserProfile } from '@/types';
import { DEFAULT_COHORTS, DEFAULT_MEMBERS } from './placeholderData';

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
      avatarUrl: row.profiles.avatar_url,
      vpaId: row.profiles.vpa_id,
      phoneNumber: row.profiles.phone_number,
      isGuest: row.profiles.is_guest ?? false,
      createdAt: row.profiles.created_at || row.joined_at,
    };
  }

  return {
    id: row.id,
    cohortId: row.cohort_id,
    userId: row.user_id,
    role: row.role || 'member',
    joinedAt: row.joined_at || new Date().toISOString(),
    profile,
  };
}

/**
 * Fetches all cohorts that the user belongs to, including their active members.
 * Returns default placeholder cohorts if Supabase is offline or unconfigured.
 */
export async function fetchUserCohorts(userId: string): Promise<{
  cohorts: EventCohort[];
  members: Record<string, GroupMember[]>;
}> {
  if (!isSupabaseConfigured()) {
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
      .from('event_cohorts')
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
  const fallbackMember: GroupMember = {
    id: `m_${Date.now()}`,
    cohortId: cohort.id,
    userId: creator.id,
    role: 'admin',
    joinedAt: new Date().toISOString(),
    profile: creator,
  };

  if (!isSupabaseConfigured()) {
    return { cohort, member: fallbackMember };
  }

  try {
    const { data: cohortRow, error: cohortErr } = await supabase
      .from('event_cohorts')
      .insert({
        id: cohort.id.startsWith('cohort_') ? undefined : cohort.id,
        name: cohort.name,
        description: cohort.description,
        category: cohort.category,
        custom_icon: cohort.customIcon,
        banner_url: cohort.bannerUrl || cohort.avatarUrl,
        currency: cohort.currency || 'INR',
        invite_code: cohort.inviteCode,
        created_by: creator.id,
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
        user_id: creator.id,
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
  if (!isSupabaseConfigured()) return;

  try {
    const dbPayload: any = {};
    if (updates.name !== undefined) dbPayload.name = updates.name;
    if (updates.description !== undefined) dbPayload.description = updates.description;
    if (updates.category !== undefined) dbPayload.category = updates.category;
    if (updates.customIcon !== undefined) dbPayload.custom_icon = updates.customIcon;
    if (updates.bannerUrl !== undefined || updates.avatarUrl !== undefined) {
      dbPayload.banner_url = updates.bannerUrl || updates.avatarUrl;
    }
    if (updates.currency !== undefined) dbPayload.currency = updates.currency;
    dbPayload.updated_at = new Date().toISOString();

    const { error } = await supabase
      .from('event_cohorts')
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
  inviteCode: string,
  user: UserProfile
): Promise<{ cohort: EventCohort; member: GroupMember } | null> {
  if (!isSupabaseConfigured()) {
    const found = DEFAULT_COHORTS.find(
      (c) => c.inviteCode.toUpperCase() === inviteCode.trim().toUpperCase()
    );
    if (found) {
      const fallbackMember: GroupMember = {
        id: `m_${Date.now()}`,
        cohortId: found.id,
        userId: user.id,
        role: 'member',
        joinedAt: new Date().toISOString(),
        profile: user,
      };
      return { cohort: found, member: fallbackMember };
    }
    return null;
  }

  try {
    const cleanCode = inviteCode.trim().toUpperCase();

    // Find cohort
    const { data: cohortRow, error: cohortErr } = await supabase
      .from('event_cohorts')
      .select('*')
      .ilike('invite_code', cleanCode)
      .maybeSingle();

    if (cohortErr) throw cohortErr;
    if (!cohortRow) return null;

    const cohort = mapCohortRow(cohortRow);

    // Join group_members if not already joined
    const { data: memberRow, error: memberErr } = await supabase
      .from('group_members')
      .upsert(
        {
          cohort_id: cohort.id,
          user_id: user.id,
          role: 'member',
        },
        { onConflict: 'cohort_id,user_id' }
      )
      .select('*, profiles:user_id(*)')
      .single();

    if (memberErr) throw memberErr;

    const member = mapMemberRow(memberRow);
    return { cohort, member };
  } catch (err) {
    console.warn(`[GroupService] joinCohortByInviteCode fallback for ${inviteCode}:`, err);
    const found = DEFAULT_COHORTS.find(
      (c) => c.inviteCode.toUpperCase() === inviteCode.trim().toUpperCase()
    );
    if (found) {
      const fallbackMember: GroupMember = {
        id: `m_${Date.now()}`,
        cohortId: found.id,
        userId: user.id,
        role: 'member',
        joinedAt: new Date().toISOString(),
        profile: user,
      };
      return { cohort: found, member: fallbackMember };
    }
    return null;
  }
}

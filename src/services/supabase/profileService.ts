import { supabase, isSupabaseConfigured } from './client';
import { UserProfile } from '@/types';
import { DEFAULT_CURRENT_USER } from './placeholderData';

/**
 * Maps Supabase raw database profile row to TypeScript domain model
 */
function mapProfileRow(row: any): UserProfile {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    avatarUrl: row.avatar_url,
    vpaId: row.vpa_id,
    phoneNumber: row.phone_number,
    isGuest: row.is_guest ?? false,
    createdAt: row.created_at || new Date().toISOString(),
  };
}

/**
 * Fetches user profile by ID from Supabase with graceful fallback
 */
export async function fetchProfile(userId: string): Promise<UserProfile | null> {
  if (!isSupabaseConfigured()) {
    return userId === DEFAULT_CURRENT_USER.id ? DEFAULT_CURRENT_USER : null;
  }

  try {
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .maybeSingle();

    if (error) throw error;
    if (!data) return null;

    return mapProfileRow(data);
  } catch (err) {
    console.warn(`[ProfileService] fetchProfile fallback for ${userId}:`, err);
    if (userId === DEFAULT_CURRENT_USER.id) {
      return DEFAULT_CURRENT_USER;
    }
    return null;
  }
}

/**
 * Updates an existing user profile in Supabase
 */
export async function updateProfile(
  userId: string,
  updates: Partial<UserProfile>
): Promise<UserProfile> {
  if (!isSupabaseConfigured()) {
    return {
      ...DEFAULT_CURRENT_USER,
      ...updates,
    };
  }

  const dbPayload: any = {};
  if (updates.fullName !== undefined) dbPayload.full_name = updates.fullName;
  if (updates.avatarUrl !== undefined) dbPayload.avatar_url = updates.avatarUrl;
  if (updates.vpaId !== undefined) dbPayload.vpa_id = updates.vpaId;
  if (updates.phoneNumber !== undefined) dbPayload.phone_number = updates.phoneNumber;
  if (updates.isGuest !== undefined) dbPayload.is_guest = updates.isGuest;

  try {
    const { data, error } = await supabase
      .from('profiles')
      .update(dbPayload)
      .eq('id', userId)
      .select()
      .single();

    if (error) throw error;
    return mapProfileRow(data);
  } catch (err) {
    console.warn(`[ProfileService] updateProfile fallback for ${userId}:`, err);
    return {
      ...DEFAULT_CURRENT_USER,
      ...updates,
    };
  }
}

/**
 * Retrieves the currently logged in or guest profile from Supabase auth
 */
export async function getCurrentProfile(): Promise<UserProfile> {
  if (!isSupabaseConfigured()) {
    return DEFAULT_CURRENT_USER;
  }

  try {
    const { data: authData } = await supabase.auth.getUser();
    if (authData?.user?.id) {
      const liveProfile = await fetchProfile(authData.user.id);
      if (liveProfile) return liveProfile;
    }
    return DEFAULT_CURRENT_USER;
  } catch (err) {
    console.warn('[ProfileService] getCurrentProfile fallback:', err);
    return DEFAULT_CURRENT_USER;
  }
}

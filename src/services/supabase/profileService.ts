import { supabase, isSupabaseConfigured } from './client';
import { UserProfile } from '@/types';
import { DEFAULT_CURRENT_USER } from './placeholderData';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function isUuid(id: string | null | undefined): boolean {
  return Boolean(id && typeof id === 'string' && UUID_REGEX.test(id));
}

/**
 * Maps Supabase raw database profile row to TypeScript domain model
 */
function mapProfileRow(row: any): UserProfile {
  return {
    id: row.id,
    fullName: row.full_name,
    email: row.email,
    nickname: row.nickname,
    username: row.username,
    avatarUrl: row.avatar_url,
    vpaId: row.vpa_id,
    phoneNumber: row.phone_number,
    isGuest: row.is_guest ?? false,
    authProvider: row.auth_provider || 'email',
    createdAt: row.created_at || new Date().toISOString(),
  };
}

/**
 * Fetches user profile by ID from Supabase with graceful fallback
 */
export async function fetchProfile(userId: string): Promise<UserProfile | null> {
  if (!isSupabaseConfigured() || !isUuid(userId)) {
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

  // Get active session user to ensure RLS compliance
  const { data: sessionData } = await supabase.auth.getSession();
  const activeUserId = sessionData?.session?.user?.id || userId;

  if (!isUuid(activeUserId)) {
    return {
      ...DEFAULT_CURRENT_USER,
      ...updates,
    };
  }

  const dbPayload: any = {};
  if (updates.fullName !== undefined) dbPayload.full_name = updates.fullName;
  if (updates.nickname !== undefined) dbPayload.nickname = updates.nickname;
  if (updates.username !== undefined) dbPayload.username = updates.username;
  if (updates.avatarUrl !== undefined) dbPayload.avatar_url = updates.avatarUrl;
  if (updates.vpaId !== undefined) dbPayload.vpa_id = updates.vpaId;
  if (updates.phoneNumber !== undefined) dbPayload.phone_number = updates.phoneNumber;
  if (updates.isGuest !== undefined) dbPayload.is_guest = updates.isGuest;
  if (updates.authProvider !== undefined) dbPayload.auth_provider = updates.authProvider;
  dbPayload.updated_at = new Date().toISOString();

  try {
    // 1. Try direct update first on the existing profile record
    const { data: updatedData, error: updateError } = await supabase
      .from('profiles')
      .update(dbPayload)
      .eq('id', activeUserId)
      .select()
      .maybeSingle();

    if (!updateError && updatedData) {
      return mapProfileRow(updatedData);
    }

    // 2. If record does not exist yet, fallback to upsert with guaranteed non-null fields
    const defaultFullName =
      updates.fullName?.trim() ||
      updates.nickname?.trim() ||
      updates.username?.trim() ||
      'You';

    const upsertPayload = {
      id: activeUserId,
      full_name: defaultFullName,
      is_guest: true,
      auth_provider: 'guest',
      ...dbPayload,
    };

    const { data: upsertData, error: upsertError } = await supabase
      .from('profiles')
      .upsert(upsertPayload)
      .select()
      .maybeSingle();

    if (upsertError) throw upsertError;
    if (upsertData) {
      return mapProfileRow(upsertData);
    }

    return {
      ...DEFAULT_CURRENT_USER,
      id: activeUserId,
      ...updates,
    };
  } catch (err) {
    console.warn(`[ProfileService] updateProfile fallback for ${activeUserId}:`, err);
    return {
      ...DEFAULT_CURRENT_USER,
      id: activeUserId,
      ...updates,
    };
  }
}

/**
 * Retrieves or initializes the currently logged in or guest profile from Supabase auth
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

      const metaName =
        authData.user.user_metadata?.full_name ||
        authData.user.user_metadata?.name ||
        authData.user.email?.split('@')[0] ||
        'You';

      const avatarUrl =
        authData.user.user_metadata?.avatar_url ||
        authData.user.user_metadata?.picture;

      // Upsert initial profile for authenticated user
      const newProfile: UserProfile = {
        id: authData.user.id,
        email: authData.user.email || '',
        fullName: metaName,
        avatarUrl,
        isGuest: false,
        authProvider: (authData.user.app_metadata?.provider as any) || 'email',
        createdAt: new Date().toISOString(),
      };

      await supabase.from('profiles').upsert({
        id: authData.user.id,
        email: authData.user.email,
        full_name: metaName,
        avatar_url: avatarUrl,
        is_guest: false,
        auth_provider: authData.user.app_metadata?.provider || 'email',
      });

      return newProfile;
    }
    return DEFAULT_CURRENT_USER;
  } catch (err) {
    console.warn('[ProfileService] getCurrentProfile error:', err);
    return DEFAULT_CURRENT_USER;
  }
}

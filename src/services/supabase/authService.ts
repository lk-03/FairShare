import { supabase, isSupabaseConfigured } from './client';
import { UserProfile } from '@/types';
import { DEFAULT_CURRENT_USER } from './placeholderData';
import * as WebBrowser from 'expo-web-browser';
import * as Linking from 'expo-linking';

WebBrowser.maybeCompleteAuthSession();

import { NativeModules } from 'react-native';

const GOOGLE_WEB_CLIENT_ID = process.env.EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID || '';

/**
 * Safely access GoogleSignin only if the native TurboModule is compiled into the binary.
 * In Expo Go, RNGoogleSignin is absent so it returns null cleanly without throwing TurboModuleRegistry errors.
 */
function getNativeGoogleSignin() {
  try {
    const hasNativeModule = Boolean(
      NativeModules.RNGoogleSignin ||
      (global as any).__turboModuleProxy?.('RNGoogleSignin')
    );
    if (!hasNativeModule) {
      return null;
    }
    const RNGoogleSignin = require('@react-native-google-signin/google-signin');
    if (RNGoogleSignin?.GoogleSignin) {
      RNGoogleSignin.GoogleSignin.configure({
        webClientId: GOOGLE_WEB_CLIENT_ID,
        scopes: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email'],
        offlineAccess: true,
      });
      return RNGoogleSignin.GoogleSignin;
    }
  } catch (e) {
    // Native TurboModule not present
  }
  return null;
}

/**
 * Service managing Supabase Cloud Authentication (Google + Email)
 */

/**
 * Native Google Sign-In with Android account picker popup (Google Play Services).
 * Falls back safely to in-app Web OAuth when running inside Expo Go.
 */
export async function signInWithNativeGoogle(): Promise<UserProfile | null> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase is not configured. Please add your credentials to .env.');
  }

  const nativeGoogle = getNativeGoogleSignin();
  if (nativeGoogle) {
    try {
      await nativeGoogle.hasPlayServices({ showPlayServicesUpdateDialog: true });
      const response = await nativeGoogle.signIn();
      const idToken = response.data?.idToken || (response as any).idToken;

      if (idToken) {
        // Exchange ID token directly with Supabase
        const { data, error } = await supabase.auth.signInWithIdToken({
          provider: 'google',
          token: idToken,
        });

        if (error) throw error;
        if (data.user) {
          const user = data.user;
          const fullName =
            user.user_metadata?.full_name ||
            user.user_metadata?.name ||
            user.email?.split('@')[0] ||
            'User';
          const avatarUrl = user.user_metadata?.avatar_url || user.user_metadata?.picture;

          // Fetch existing profile to preserve custom username/nickname/vpaId
          const { data: existingProfile } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();

          const finalFullName = existingProfile?.full_name || fullName;
          const finalAvatar = existingProfile?.avatar_url || avatarUrl;

          // Upsert profile in Supabase
          await supabase.from('profiles').upsert({
            id: user.id,
            email: user.email,
            full_name: finalFullName,
            nickname: existingProfile?.nickname,
            username: existingProfile?.username,
            avatar_url: finalAvatar,
            vpa_id: existingProfile?.vpa_id,
            is_guest: false,
            auth_provider: 'google',
          });

          return {
            id: user.id,
            email: user.email || '',
            fullName: finalFullName,
            nickname: existingProfile?.nickname,
            username: existingProfile?.username,
            avatarUrl: finalAvatar,
            vpaId: existingProfile?.vpa_id,
            phoneNumber: existingProfile?.phone_number,
            isGuest: false,
            authProvider: 'google',
            createdAt: user.created_at || new Date().toISOString(),
          };
        }
      }
    } catch (nativeErr: any) {
      console.warn('[AuthService] Native Google Sign-In notice:', nativeErr);
      if (nativeErr?.code === 'SIGN_IN_CANCELLED' || nativeErr?.message?.includes('cancelled')) {
        return null;
      }
    }
  }

  // Seamless fallback to Web OAuth
  return signInWithGoogleOAuth();
}

export async function signInWithGoogleOAuth(): Promise<UserProfile | null> {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase is not configured. Please add your credentials to .env.');
  }

  const redirectUrl = Linking.createURL('/welcome');
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: redirectUrl,
      skipBrowserRedirect: true,
    },
  });

  if (error) throw error;
  if (!data?.url) throw new Error('No OAuth URL returned by Supabase.');

  const res = await WebBrowser.openAuthSessionAsync(data.url, redirectUrl);

  if (res.type === 'success' && res.url) {
    const parsed = Linking.parse(res.url);

    // 1. Handle PKCE code in query params (?code=...)
    const code =
      (parsed.queryParams?.code as string) ||
      new URLSearchParams(res.url.split('?')[1] || '').get('code');
    if (code) {
      const { error: exchangeErr } = await supabase.auth.exchangeCodeForSession(code);
      if (exchangeErr) console.warn('[AuthService] Exchange code error:', exchangeErr);
    }

    // 2. Handle token fragment (#access_token=...&refresh_token=...)
    const fragment = res.url.split('#')[1];
    if (fragment) {
      const params = new URLSearchParams(fragment);
      const accessToken = params.get('access_token');
      const refreshToken = params.get('refresh_token');
      if (accessToken && refreshToken) {
        await supabase.auth.setSession({
          access_token: accessToken,
          refresh_token: refreshToken,
        });
      }
    }
  }

  // 3. Retrieve authenticated user from session
  const { data: sessionData } = await supabase.auth.getSession();
  let user: any = sessionData?.session?.user;

  if (!user) {
    const { data: userData } = await supabase.auth.getUser();
    user = userData?.user;
  }

  if (user) {
    const fullName =
      user.user_metadata?.full_name ||
      user.user_metadata?.name ||
      user.email?.split('@')[0] ||
      'User';
    const avatarUrl = user.user_metadata?.avatar_url || user.user_metadata?.picture;

    // Fetch existing profile to preserve custom username/nickname/vpaId
    const { data: existingProfile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    const finalFullName = existingProfile?.full_name || fullName;
    const finalAvatar = existingProfile?.avatar_url || avatarUrl;

    // Upsert profile in Supabase
    await supabase.from('profiles').upsert({
      id: user.id,
      email: user.email,
      full_name: finalFullName,
      nickname: existingProfile?.nickname,
      username: existingProfile?.username,
      avatar_url: finalAvatar,
      vpa_id: existingProfile?.vpa_id,
      is_guest: false,
      auth_provider: 'google',
    });

    return {
      id: user.id,
      email: user.email || '',
      fullName: finalFullName,
      nickname: existingProfile?.nickname,
      username: existingProfile?.username,
      avatarUrl: finalAvatar,
      vpaId: existingProfile?.vpa_id,
      phoneNumber: existingProfile?.phone_number,
      isGuest: false,
      authProvider: 'google',
      createdAt: user.created_at || new Date().toISOString(),
    };
  }

  return null;
}

export async function signInWithEmail(email: string, password: string): Promise<UserProfile | null> {
  if (!isSupabaseConfigured()) {
    return {
      ...DEFAULT_CURRENT_USER,
      email,
      fullName: email.split('@')[0] || 'User',
      isGuest: false,
      authProvider: 'email',
    };
  }

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) {
      if (error.message?.includes('Email not confirmed')) {
        throw new Error(
          'Email not confirmed yet. Please check your email inbox to confirm your account, or click "Resend Email".'
        );
      }
      throw error;
    }
    if (!data.user) return null;

    const { data: profileRow } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', data.user.id)
      .maybeSingle();

    return {
      id: data.user.id,
      email: data.user.email || email,
      fullName: profileRow?.full_name || email.split('@')[0] || 'User',
      nickname: profileRow?.nickname,
      username: profileRow?.username,
      avatarUrl: profileRow?.avatar_url,
      vpaId: profileRow?.vpa_id,
      phoneNumber: profileRow?.phone_number,
      isGuest: false,
      authProvider: 'email',
      createdAt: data.user.created_at || new Date().toISOString(),
    };
  } catch (err) {
    console.warn('[AuthService] Email sign in error:', err);
    throw err;
  }
}

export async function signUpWithEmail(
  email: string,
  password: string,
  fullName: string
): Promise<{ user: UserProfile | null; requiresEmailConfirmation: boolean }> {
  if (!isSupabaseConfigured()) {
    return {
      user: {
        ...DEFAULT_CURRENT_USER,
        email,
        fullName,
        isGuest: false,
        authProvider: 'email',
      },
      requiresEmailConfirmation: false,
    };
  }

  try {
    const redirectUrl = Linking.createURL('/welcome');
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName },
        emailRedirectTo: redirectUrl,
      },
    });
    if (error) throw error;
    if (!data.user) return { user: null, requiresEmailConfirmation: true };

    const requiresEmailConfirmation = !data.session;

    // Create profile
    await supabase.from('profiles').upsert({
      id: data.user.id,
      email,
      full_name: fullName,
      is_guest: false,
      auth_provider: 'email',
    });

    return {
      user: {
        id: data.user.id,
        email,
        fullName,
        isGuest: false,
        authProvider: 'email',
        createdAt: data.user.created_at || new Date().toISOString(),
      },
      requiresEmailConfirmation,
    };
  } catch (err) {
    console.warn('[AuthService] Email sign up error:', err);
    throw err;
  }
}

export async function resendConfirmationEmail(email: string): Promise<void> {
  if (!isSupabaseConfigured()) return;
  const redirectUrl = Linking.createURL('/welcome');
  const { error } = await supabase.auth.resend({
    type: 'signup',
    email,
    options: {
      emailRedirectTo: redirectUrl,
    },
  });
  if (error) throw error;
}

export async function signOut(): Promise<void> {
  if (isSupabaseConfigured()) {
    try {
      await supabase.auth.signOut();
    } catch (err) {
      console.warn('[AuthService] Sign out error:', err);
    }
  }
}

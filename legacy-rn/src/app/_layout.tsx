import { Buffer } from 'buffer';
global.Buffer = global.Buffer || Buffer;

import '../global.css';

import React, { useEffect } from 'react';
import { View, useColorScheme, StatusBar } from 'react-native';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import * as Linking from 'expo-linking';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { configureReanimatedLogger, ReanimatedLogLevel } from 'react-native-reanimated';
import { AnimatedSplashOverlay } from '@/components/animated-icon';
import { CustomAlertModal } from '@/components/ui/CustomAlertModal';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { supabase, isSupabaseConfigured } from '@/services/supabase/client';

configureReanimatedLogger({
  level: ReanimatedLogLevel.warn,
  strict: false,
});

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();

  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  useEffect(() => {
    const handleDeepLink = async (event: { url: string }) => {
      if (!isSupabaseConfigured() || !event.url) return;
      try {
        const parsed = Linking.parse(event.url);
        const code =
          (parsed.queryParams?.code as string) ||
          new URLSearchParams(event.url.split('?')[1] || '').get('code');
        if (code) {
          await supabase.auth.exchangeCodeForSession(code);
        }
        const fragment = event.url.split('#')[1];
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
      } catch (e) {
        console.warn('[RootLayout] Deep link auth handle error:', e);
      }
    };

    const sub = Linking.addEventListener('url', handleDeepLink);
    Linking.getInitialURL().then((url) => {
      if (url) handleDeepLink({ url });
    });

    let authSubscription: { unsubscribe: () => void } | null = null;
    if (isSupabaseConfigured()) {
      const { data } = supabase.auth.onAuthStateChange(async (_event, session) => {
        // Keeps the session synchronized when tokens are refreshed in background
      });
      authSubscription = data.subscription;
    }

    return () => {
      sub.remove();
      authSubscription?.unsubscribe();
    };
  }, []);

  return (
    <SafeAreaProvider>
      <View className={`flex-1 ${activeThemeClass} bg-screen`}>
        <StatusBar barStyle={isDark ? 'light-content' : 'dark-content'} />
        <AnimatedSplashOverlay />
        <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: 'transparent' } }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="welcome" />
          <Stack.Screen name="event/[id]" />
          <Stack.Screen name="scan" options={{ presentation: 'modal' }} />
        </Stack>
        <CustomAlertModal />
      </View>
    </SafeAreaProvider>
  );
}

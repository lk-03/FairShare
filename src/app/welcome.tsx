import React, { useState, useEffect } from 'react';
import { View, useColorScheme } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useExpenseStore } from '../store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '../store/useThemeStore';
import { showAlert } from '../store/useAlertStore';
import { OnboardingCarousel } from '../components/onboarding/OnboardingCarousel';
import { AuthModal } from '../components/onboarding/AuthModal';
import { FirstTimeSetupModal } from '../components/onboarding/FirstTimeSetupModal';
import { UserProfile } from '../types';

export default function WelcomeScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ mode?: string }>();
  const isTourOnly = params.mode === 'tour';

  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const {
    setHasCompletedOnboarding,
    fetchInitialData,
    hasSeenAppTour,
    setHasSeenAppTour,
    setCurrentUser,
  } = useExpenseStore();

  const [step, setStep] = useState<'carousel' | 'auth' | 'setup'>(() => {
    if (isTourOnly) return 'carousel';
    if (hasSeenAppTour) return 'auth';
    return 'carousel';
  });

  useEffect(() => {
    if (isTourOnly) {
      setStep('carousel');
    }
  }, [isTourOnly]);

  const handleFinishOnboarding = async () => {
    setHasCompletedOnboarding(true);
    setHasSeenAppTour(true);
    await fetchInitialData();
    if (isTourOnly) {
      router.back();
    } else {
      router.replace('/(tabs)');
    }
  };

  const handleTourDismiss = () => {
    setHasSeenAppTour(true);
    if (isTourOnly) {
      router.back();
    } else {
      setStep('auth');
    }
  };

  const handleAuthenticated = async (data: {
    provider: 'google' | 'email';
    email: string;
    fullName: string;
    isNewUser?: boolean;
    userProfile?: UserProfile;
  }) => {
    setAuthData(data);

    if (data.isNewUser === false) {
      // Existing user: skip FirstTimeSetupModal, update state, and navigate
      setHasCompletedOnboarding(true);
      setHasSeenAppTour(true);
      if (data.userProfile) {
        setCurrentUser(data.userProfile);
      }
      await fetchInitialData();
      const displayName = data.userProfile?.nickname || data.userProfile?.fullName || data.fullName || 'friend';
      showAlert('Welcome Back', `Welcome back to FairShare, ${displayName}!`);

      if (isTourOnly) {
        router.back();
      } else {
        router.replace('/(tabs)');
      }
      return;
    }

    // New user without customized username/avatar
    setStep('setup');
  };

  const [authData, setAuthData] = useState<{
    provider: 'google' | 'email';
    email: string;
    fullName: string;
  } | null>(null);

  return (
    <View
      className={`flex-1 ${activeThemeClass}`}
      style={{ backgroundColor: colors.screen }}
    >
      {step === 'carousel' && (
        <OnboardingCarousel
          onComplete={handleTourDismiss}
          onSkip={handleTourDismiss}
        />
      )}

      {step === 'auth' && (
        <AuthModal
          onAuthenticated={handleAuthenticated}
          onBack={isTourOnly ? () => router.back() : undefined}
        />
      )}

      {step === 'setup' && (
        <FirstTimeSetupModal
          initialName={authData?.fullName}
          initialEmail={authData?.email}
          onFinish={handleFinishOnboarding}
        />
      )}
    </View>
  );
}

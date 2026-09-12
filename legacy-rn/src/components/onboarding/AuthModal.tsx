import React, { useState } from 'react';
import {
  View,
  Text,
  Image,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  useColorScheme,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useThemeStore, getThemePalette, getActiveThemeClass } from '../../store/useThemeStore';
import { showAlert } from '../../store/useAlertStore';
import * as authService from '../../services/supabase/authService';
import { AppLogo } from '../ui/AppLogo';

interface AuthModalProps {
  onAuthenticated: (authData: {
    provider: 'google' | 'email';
    email: string;
    fullName: string;
    isNewUser?: boolean;
    userProfile?: any;
  }) => void;
  onBack?: () => void;
}

export function AuthModal({ onAuthenticated, onBack }: AuthModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const [authMode, setAuthMode] = useState<'options' | 'email_signin' | 'email_signup' | 'email_verify'>('options');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [name, setName] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [resendCooldown, setResendCooldown] = useState(0);

  const handleGoogleAuth = async () => {
    setIsLoading(true);
    try {
      const user = await authService.signInWithNativeGoogle();
      setIsLoading(false);
      if (user) {
        onAuthenticated({
          provider: 'google',
          email: user.email || 'user@gmail.com',
          fullName: user.fullName || 'User',
          isNewUser: false,
          userProfile: user,
        });
      }
    } catch (err: any) {
      setIsLoading(false);
      showAlert(
        'Google Sign-In Notice',
        err?.message ||
          'To use Google Sign-In, please enable Google Provider in your Supabase Dashboard or sign in with Email below.'
      );
    }
  };

  const handleEmailSubmit = async () => {
    if (!email.trim() || !email.includes('@')) {
      showAlert('Invalid Email', 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      showAlert('Password Required', 'Password must be at least 6 characters.');
      return;
    }
    if (authMode === 'email_signup' && !name.trim()) {
      showAlert('Name Required', 'Please enter your name.');
      return;
    }

    setIsLoading(true);
    try {
      if (authMode === 'email_signup') {
        const result = await authService.signUpWithEmail(email.trim(), password, name.trim());
        setIsLoading(false);
        if (result.requiresEmailConfirmation) {
          setAuthMode('email_verify');
          showAlert(
            'Confirmation Email Sent',
            `We have sent a verification link to ${email.trim()}. Please check your inbox!`
          );
        } else if (result.user) {
          onAuthenticated({
            provider: 'email',
            email: email.trim(),
            fullName: name.trim(),
            isNewUser: true,
            userProfile: result.user,
          });
        }
      } else {
        const user = await authService.signInWithEmail(email.trim(), password);
        setIsLoading(false);
        if (user) {
          onAuthenticated({
            provider: 'email',
            email: email.trim(),
            fullName: user.fullName || email.split('@')[0],
            isNewUser: false,
            userProfile: user,
          });
        }
      }
    } catch (err: any) {
      setIsLoading(false);
      showAlert(
        authMode === 'email_signup' ? 'Sign Up Failed' : 'Sign In Failed',
        err?.message || 'Could not authenticate. Please check your credentials.'
      );
    }
  };

  const handleResendVerification = async () => {
    if (resendCooldown > 0) return;
    setIsLoading(true);
    try {
      await authService.resendConfirmationEmail(email.trim());
      setIsLoading(false);
      showAlert('Email Resent', `A new verification email has been sent to ${email.trim()}`);
      setResendCooldown(30);
      const interval = setInterval(() => {
        setResendCooldown((prev) => {
          if (prev <= 1) {
            clearInterval(interval);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } catch (err: any) {
      setIsLoading(false);
      showAlert('Resend Failed', err?.message || 'Could not resend verification email.');
    }
  };

  const handleCheckVerification = async () => {
    setIsLoading(true);
    try {
      const user = await authService.signInWithEmail(email.trim(), password);
      setIsLoading(false);
      if (user) {
        onAuthenticated({
          provider: 'email',
          email: email.trim(),
          fullName: user.fullName || name.trim() || email.split('@')[0],
          isNewUser: false,
          userProfile: user,
        });
      }
    } catch (err: any) {
      setIsLoading(false);
      showAlert('Not Verified Yet', err?.message || 'Please click the link in your email to verify.');
    }
  };

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      className={`flex-1 ${activeThemeClass}`}
      style={{ backgroundColor: colors.screen }}
    >
      <ScrollView
        contentContainerStyle={{ flexGrow: 1, justifyContent: 'space-between', padding: 24, paddingTop: 48 }}
        keyboardShouldPersistTaps="handled"
      >
        {/* Top Header */}
        <View className="flex-row items-center justify-between">
          {onBack ? (
            <TouchableOpacity
              onPress={onBack}
              className="p-2.5 rounded-2xl border"
              style={{ backgroundColor: colors.surface, borderColor: colors.border }}
              activeOpacity={0.7}
            >
              <Ionicons name="arrow-back" size={20} color={colors.textMain} />
            </TouchableOpacity>
          ) : (
            <View className="w-10" />
          )}

          <View className="flex-row items-center gap-2">
            <AppLogo size={28} withShadow withGlow />
            <Text className="text-lg font-black tracking-tight" style={{ color: colors.textMain }}>
              FairShare
            </Text>
          </View>

          <View className="w-10" />
        </View>

        {/* Main Content Area */}
        <View className="gap-6 my-auto max-w-sm w-full self-center">
          {authMode === 'email_verify' ? (
            /* Email Verification Waiting Card */
            <View className="gap-5 items-center">
              <View
                className="w-20 h-20 rounded-3xl items-center justify-center border shadow-sm"
                style={{ backgroundColor: `${colors.cyan}15`, borderColor: `${colors.cyan}40` }}
              >
                <Ionicons name="mail-unread-outline" size={38} color={colors.cyan} />
              </View>

              <View className="gap-1.5 items-center text-center">
                <Text className="text-2xl font-black text-center" style={{ color: colors.textMain }}>
                  Check Your Inbox
                </Text>
                <Text className="text-xs font-semibold text-center leading-5 px-2" style={{ color: colors.textSecondary }}>
                  We sent a confirmation link to:
                </Text>
                <Text className="text-sm font-black text-center px-2" style={{ color: colors.cyan }}>
                  {email}
                </Text>
                <Text className="text-xs font-semibold text-center leading-5 px-2 mt-1" style={{ color: colors.textSecondary }}>
                  Click the link in your email to activate your account.
                </Text>
              </View>

              <View className="w-full gap-3 mt-2">
                <TouchableOpacity
                  onPress={handleCheckVerification}
                  disabled={isLoading}
                  className="h-14 rounded-2xl items-center justify-center shadow-md"
                  style={{ backgroundColor: colors.cyan }}
                  activeOpacity={0.85}
                >
                  {isLoading ? (
                    <ActivityIndicator size="small" color="#0F172A" />
                  ) : (
                    <Text className="text-sm font-black text-slate-900">
                      I've Verified (Continue)
                    </Text>
                  )}
                </TouchableOpacity>

                <TouchableOpacity
                  onPress={handleResendVerification}
                  disabled={isLoading || resendCooldown > 0}
                  className="h-12 rounded-2xl items-center justify-center border"
                  style={{
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                    opacity: resendCooldown > 0 ? 0.6 : 1,
                  }}
                  activeOpacity={0.8}
                >
                  <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                    {resendCooldown > 0
                      ? `Resend in ${resendCooldown}s`
                      : 'Resend Verification Email'}
                  </Text>
                </TouchableOpacity>

                <TouchableOpacity
                  onPress={() => setAuthMode('email_signin')}
                  className="items-center py-2"
                  activeOpacity={0.7}
                >
                  <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                    Back to Sign In
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          ) : (
            <>
              {/* Title Card */}
              <View className="gap-2 items-center text-center">
                <View
                  className="px-3 py-1 rounded-full border mb-1"
                  style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                >
                  <Text className="text-[10px] font-black uppercase tracking-wider" style={{ color: colors.cyan }}>
                    Cloud-Synced Group Ledger
                  </Text>
                </View>
                <Text className="text-2xl font-black text-center" style={{ color: colors.textMain }}>
                  {authMode === 'options'
                    ? 'Welcome to FairShare'
                    : authMode === 'email_signin'
                    ? 'Sign in with Email'
                    : 'Create FairShare Account'}
                </Text>
                <Text
                  className="text-xs font-semibold text-center leading-5 px-2"
                  style={{ color: colors.textSecondary }}
                >
                  {authMode === 'options'
                    ? 'Split transparently with roommates, trips, and friends with real-time cloud sync'
                    : 'Enter your credentials to access your cloud-synced ledgers'}
                </Text>
              </View>

              {authMode === 'options' ? (
                /* Main Auth Option Buttons */
                <View className="gap-3.5">
                  {/* Google Sign In */}
                  <TouchableOpacity
                    onPress={handleGoogleAuth}
                    disabled={isLoading}
                    className="h-14 rounded-2xl flex-row items-center justify-center gap-3 border shadow-sm"
                    style={{
                      backgroundColor: colors.surface,
                      borderColor: colors.border,
                    }}
                    activeOpacity={0.8}
                  >
                    {isLoading ? (
                      <ActivityIndicator size="small" color={colors.cyan} />
                    ) : (
                      <>
                        <Ionicons name="logo-google" size={18} color="#EA4335" />
                        <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                          Continue with Google
                        </Text>
                      </>
                    )}
                  </TouchableOpacity>

                  {/* Email Sign In */}
                  <TouchableOpacity
                    onPress={() => setAuthMode('email_signin')}
                    className="h-14 rounded-2xl flex-row items-center justify-center gap-3 border"
                    style={{
                      backgroundColor: colors.accentPill,
                      borderColor: colors.border,
                    }}
                    activeOpacity={0.8}
                  >
                    <Ionicons name="mail-outline" size={18} color={colors.cyan} />
                    <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                      Continue with Email
                    </Text>
                  </TouchableOpacity>

                  {/* Sign up prompt */}
                  <TouchableOpacity
                    onPress={() => setAuthMode('email_signup')}
                    className="items-center py-2"
                    activeOpacity={0.7}
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                      New to FairShare? Create an Account
                    </Text>
                  </TouchableOpacity>
                </View>
              ) : (
                /* Email Form */
                <View className="gap-3.5">
                  {authMode === 'email_signup' && (
                    <View className="gap-1.5">
                      <Text
                        className="text-[11px] font-black uppercase tracking-wider px-1"
                        style={{ color: colors.textSecondary }}
                      >
                        Full Name
                      </Text>
                      <TextInput
                        className="h-12 px-4 rounded-2xl text-sm font-bold border"
                        style={{
                          backgroundColor: colors.surface,
                          borderColor: colors.border,
                          color: colors.textMain,
                        }}
                        placeholder="e.g. Alex Doe"
                        placeholderTextColor={colors.textSecondary}
                        value={name}
                        onChangeText={setName}
                      />
                    </View>
                  )}

                  <View className="gap-1.5">
                    <Text
                      className="text-[11px] font-black uppercase tracking-wider px-1"
                      style={{ color: colors.textSecondary }}
                    >
                      Email Address
                    </Text>
                    <TextInput
                      className="h-12 px-4 rounded-2xl text-sm font-bold border"
                      style={{
                        backgroundColor: colors.surface,
                        borderColor: colors.border,
                        color: colors.textMain,
                      }}
                      placeholder="name@example.com"
                      placeholderTextColor={colors.textSecondary}
                      keyboardType="email-address"
                      autoCapitalize="none"
                      value={email}
                      onChangeText={setEmail}
                    />
                  </View>

                  <View className="gap-1.5">
                    <Text
                      className="text-[11px] font-black uppercase tracking-wider px-1"
                      style={{ color: colors.textSecondary }}
                    >
                      Password
                    </Text>
                    <View
                      className="flex-row items-center h-12 px-4 rounded-2xl border"
                      style={{
                        backgroundColor: colors.surface,
                        borderColor: colors.border,
                      }}
                    >
                      <TextInput
                        className="flex-1 text-sm font-bold"
                        style={{ color: colors.textMain }}
                        placeholder="••••••••"
                        placeholderTextColor={colors.textSecondary}
                        secureTextEntry={!showPassword}
                        value={password}
                        onChangeText={setPassword}
                      />
                      <TouchableOpacity onPress={() => setShowPassword(!showPassword)} activeOpacity={0.7}>
                        <Ionicons
                          name={showPassword ? 'eye-off-outline' : 'eye-outline'}
                          size={18}
                          color={colors.textSecondary}
                        />
                      </TouchableOpacity>
                    </View>
                  </View>

                  <TouchableOpacity
                    onPress={handleEmailSubmit}
                    disabled={isLoading}
                    className="h-14 rounded-2xl items-center justify-center mt-2 shadow-md"
                    style={{ backgroundColor: colors.cyan }}
                    activeOpacity={0.85}
                  >
                    {isLoading ? (
                      <ActivityIndicator size="small" color="#0F172A" />
                    ) : (
                      <Text className="text-sm font-black text-slate-900">
                        {authMode === 'email_signin' ? 'Sign In' : 'Create Account'}
                      </Text>
                    )}
                  </TouchableOpacity>

                  <TouchableOpacity
                    onPress={() =>
                      setAuthMode(authMode === 'email_signin' ? 'email_signup' : 'email_signin')
                    }
                    className="items-center py-2"
                    activeOpacity={0.7}
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                      {authMode === 'email_signin'
                        ? "Don't have an account? Sign Up"
                        : 'Already have an account? Sign In'}
                    </Text>
                  </TouchableOpacity>

                  <TouchableOpacity
                    onPress={() => setAuthMode('options')}
                    className="items-center py-1"
                    activeOpacity={0.7}
                  >
                    <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                      Back to all sign-in options
                    </Text>
                  </TouchableOpacity>
                </View>
              )}
            </>
          )}
        </View>

        {/* Footer Legal */}
        <View className="items-center px-4 pt-4">
          <Text
            className="text-[11px] text-center font-medium leading-4"
            style={{ color: colors.textSecondary }}
          >
            By continuing, you agree to FairShare's transparent ledger terms and privacy principles.
          </Text>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

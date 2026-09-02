import React, { useState } from 'react';
import { View, ScrollView, TouchableOpacity, Image, useColorScheme } from 'react-native';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { BottomTabInset } from '@/constants/theme';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';
import { ThemeSettingsModal } from '@/components/ThemeSettingsModal';
import { SetUpiModal } from '@/components/SetUpiModal';
import { EditProfileModal } from '@/components/EditProfileModal';
import { AvatarPickerModal } from '@/components/AvatarPickerModal';
import { SplitwiseImportModal } from '@/components/SplitwiseImportModal';
import { AppLogo } from '@/components/ui/AppLogo';
import { showAlert } from '@/store/useAlertStore';
import { signOut } from '@/services/supabase/authService';
import { useRouter } from 'expo-router';

export default function ProfileScreen() {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { currentUser, setHasCompletedOnboarding } = useExpenseStore();
  const [themeModalVisible, setThemeModalVisible] = useState(false);
  const [upiModalVisible, setUpiModalVisible] = useState(false);
  const [editProfileVisible, setEditProfileVisible] = useState(false);
  const [avatarPickerVisible, setAvatarPickerVisible] = useState(false);
  const [splitwiseModalVisible, setSplitwiseModalVisible] = useState(false);

  const displayName = currentUser.nickname || currentUser.fullName || 'You';

  const handleLogout = () => {
    showAlert('Log Out', 'Are you sure you want to log out of FairShare?', [
      {
        text: 'Log Out',
        style: 'destructive',
        onPress: async () => {
          await signOut();
          setHasCompletedOnboarding(false);
          router.replace('/welcome' as any);
        },
      },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

  return (
    <View className={`flex-1 ${activeThemeClass} bg-screen`}>
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: BottomTabInset + 20 }}
        className="px-5 pt-12"
      >
        {/* Header Title */}
        <Text className="text-3xl font-extrabold text-main mb-6">Profile</Text>

        {/* Profile Card */}
        <View
          className="p-6 rounded-3xl items-center border border-surface bg-surface shadow-sm gap-4"
          style={{ borderColor: colors.border }}
        >
          {/* Avatar with Camera Icon Overlay */}
          <TouchableOpacity
            activeOpacity={0.8}
            className="relative"
            onPress={() => setAvatarPickerVisible(true)}
          >
            <View
              className="w-24 h-24 rounded-full border-2 overflow-hidden shadow-md"
              style={{ borderColor: colors.cyan, backgroundColor: colors.accentPill }}
            >
              {currentUser.avatarUrl ? (
                <Image
                  source={{ uri: currentUser.avatarUrl }}
                  className="w-full h-full"
                  resizeMode="cover"
                />
              ) : (
                <View className="w-full h-full items-center justify-center">
                  <Text className="text-3xl font-black" style={{ color: colors.cyan }}>
                    {(displayName || 'U').charAt(0).toUpperCase()}
                  </Text>
                </View>
              )}
            </View>
            <View
              className="absolute bottom-0 right-0 w-7 h-7 rounded-full items-center justify-center border shadow-sm"
              style={{ backgroundColor: colors.cyan, borderColor: colors.surface }}
            >
              <Ionicons name="camera" size={13} color="#0F172A" />
            </View>
          </TouchableOpacity>

          {/* User Name & Details Centered */}
          <View className="items-center gap-1 w-full">
            <View className="flex-row items-center gap-1.5 justify-center">
              <Text className="text-2xl font-extrabold text-main text-center">{displayName}</Text>
              {currentUser.vpaId ? (
                <Ionicons name="checkmark-circle" size={20} color={colors.cyan} />
              ) : null}
            </View>

            {currentUser.vpaId ? (
              <Text className="text-xs font-semibold text-center" style={{ color: colors.cyan }}>
                Verified UPI
              </Text>
            ) : null}

            {currentUser.username ? (
              <Text className="text-sm font-bold text-secondary text-center mt-0.5">
                @{currentUser.username}
              </Text>
            ) : null}

            {currentUser.email ? (
              <Text className="text-xs text-secondary text-center">{currentUser.email}</Text>
            ) : null}
          </View>

          {/* Detailed Edit Profile Button */}
          <TouchableOpacity
            activeOpacity={0.8}
            className="px-4 py-2 rounded-xl flex-row items-center gap-2 mt-1 shadow-sm"
            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
            onPress={() => setEditProfileVisible(true)}
          >
            <Ionicons name="create-outline" size={15} color={colors.cyan} />
            <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
              Edit Profile
            </Text>
          </TouchableOpacity>
        </View>

        {/* Options List */}
        <View className="mt-6 gap-3">
          {/* UPI Virtual Payment Address Config */}
          <TouchableOpacity
            activeOpacity={0.7}
            className="p-4 rounded-2xl flex-row items-center justify-between border border-surface bg-surface shadow-sm"
            onPress={() => setUpiModalVisible(true)}
          >
            <View className="flex-row items-center gap-3.5 flex-1 pr-2">
              <View
                className="w-10 h-10 rounded-2xl items-center justify-center"
                style={{ backgroundColor: colors.accentPill }}
              >
                <Ionicons name="card-outline" size={20} color={colors.cyan} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Payment Methods (UPI)</Text>
                <Text className="text-xs text-secondary mt-0.5" numberOfLines={1}>
                  {currentUser.vpaId ? currentUser.vpaId : 'Add UPI ID for 1-tap settlements'}
                </Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>

          {/* Import Splitwise Data */}
          <TouchableOpacity
            activeOpacity={0.7}
            className="p-4 rounded-2xl flex-row items-center justify-between border border-surface bg-surface shadow-sm"
            onPress={() => setSplitwiseModalVisible(true)}
          >
            <View className="flex-row items-center gap-3.5 flex-1 pr-2">
              <View
                className="w-10 h-10 rounded-2xl items-center justify-center"
                style={{ backgroundColor: `${colors.emerald}20` }}
              >
                <Ionicons name="swap-horizontal" size={20} color={colors.emerald} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Import Splitwise CSV</Text>
                <Text className="text-xs text-secondary mt-0.5">
                  Migrate full group history and expenses
                </Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>

          {/* Feature Guide / Onboarding Replay */}
          <TouchableOpacity
            activeOpacity={0.7}
            className="p-4 rounded-2xl flex-row items-center justify-between border border-surface bg-surface shadow-sm"
            onPress={() => router.push('/welcome?mode=tour' as any)}
          >
            <View className="flex-row items-center gap-3.5 flex-1 pr-2">
              <View
                className="w-10 h-10 rounded-2xl items-center justify-center"
                style={{ backgroundColor: colors.accentPill }}
              >
                <Ionicons name="compass-outline" size={20} color={colors.cyan} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Guide & Interactive Tour</Text>
                <Text className="text-xs text-secondary mt-0.5">
                  Learn about debt simplification and split modes
                </Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>

          {/* Theme & Appearance Config */}
          <TouchableOpacity
            activeOpacity={0.7}
            className="p-4 rounded-2xl flex-row items-center justify-between border border-surface bg-surface shadow-sm"
            onPress={() => setThemeModalVisible(true)}
          >
            <View className="flex-row items-center gap-3.5 flex-1 pr-2">
              <View
                className="w-10 h-10 rounded-2xl items-center justify-center"
                style={{ backgroundColor: colors.accentPill }}
              >
                <Ionicons name="color-palette-outline" size={20} color={colors.cyan} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Theme & Appearance</Text>
                <Text className="text-xs text-secondary mt-0.5">
                  Custom color schemes & palettes
                </Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>
        </View>

        {/* Log Out Button */}
        <TouchableOpacity
          activeOpacity={0.8}
          className="w-full rounded-2xl py-4 mt-6 border border-surface bg-surface items-center shadow-sm"
          onPress={handleLogout}
        >
          <Text className="text-base font-bold text-negative">Log Out</Text>
        </TouchableOpacity>

        {/* Brand Footer */}
        <View className="items-center justify-center py-8 gap-2">
          <View className="flex-row items-center gap-2">
            <AppLogo size={24} withShadow withGlow />
            <Text className="text-sm font-black text-main">FairShare</Text>
          </View>
          <Text className="text-[11px] font-semibold text-secondary">
            Version 1.0.0 (Build Ready)
          </Text>
        </View>
      </ScrollView>

      <ThemeSettingsModal
        visible={themeModalVisible}
        onClose={() => setThemeModalVisible(false)}
      />

      <SetUpiModal
        visible={upiModalVisible}
        onClose={() => setUpiModalVisible(false)}
      />

      <EditProfileModal
        visible={editProfileVisible}
        onClose={() => setEditProfileVisible(false)}
      />

      <AvatarPickerModal
        visible={avatarPickerVisible}
        onClose={() => setAvatarPickerVisible(false)}
      />

      <SplitwiseImportModal
        visible={splitwiseModalVisible}
        onClose={() => setSplitwiseModalVisible(false)}
        onSuccess={(cohortId) => {
          router.push(`/event/${cohortId}` as any);
        }}
      />
    </View>
  );
}

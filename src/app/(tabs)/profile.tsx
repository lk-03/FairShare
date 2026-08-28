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

export default function ProfileScreen() {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { currentUser } = useExpenseStore();
  const [themeModalVisible, setThemeModalVisible] = useState(false);
  const [upiModalVisible, setUpiModalVisible] = useState(false);
  const [editProfileVisible, setEditProfileVisible] = useState(false);
  const [avatarPickerVisible, setAvatarPickerVisible] = useState(false);

  const displayName = currentUser.nickname || currentUser.fullName;

  return (
    <View className="flex-1 bg-screen pt-safe">
      <View className="screen-header">
        <Text className="screen-title">Profile</Text>
      </View>

      <ScrollView
        contentContainerClassName="px-5 pb-10 gap-6"
        style={{ paddingBottom: BottomTabInset + 24 }}
        showsVerticalScrollIndicator={false}
      >
        {/* User Profile Card */}
        <View className="card-main p-7 items-center mt-2 gap-4">
          {/* Avatar Container with Quick Avatar Picker Trigger */}
          <TouchableOpacity
            activeOpacity={0.85}
            onPress={() => setAvatarPickerVisible(true)}
            className="relative"
          >
            <View
              className="w-24 h-24 rounded-full items-center justify-center overflow-hidden"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
                borderWidth: 2,
                borderColor: colors.border,
                elevation: 0,
                shadowOpacity: 0,
              }}
            >
              {currentUser.avatarUrl ? (
                <Image source={{ uri: currentUser.avatarUrl }} className="w-24 h-24 rounded-full" />
              ) : (
                <Text className="text-4xl font-extrabold" style={{ color: colors.textMain }}>
                  {displayName.charAt(0).toUpperCase()}
                </Text>
              )}
            </View>
            <View
              className="absolute bottom-0 right-0 w-7 h-7 rounded-full items-center justify-center shadow-sm"
              style={{ backgroundColor: colors.cyan }}
            >
              <Ionicons name="pencil" size={13} color="#0F172A" />
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

            <Text className="text-xs text-secondary text-center">{currentUser.email}</Text>
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

        {/* Account Section */}
        <View className="gap-3">
          <Text className="section-label ml-1 mb-1">ACCOUNT</Text>

          <TouchableOpacity
            activeOpacity={0.8}
            className="card-item"
            onPress={() => setUpiModalVisible(true)}
          >
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="card-outline" size={24} color={colors.cyan} />
              <View className="flex-1">
                <View className="flex-row items-center gap-2">
                  <Text className="text-base font-bold text-main">Payment Methods</Text>
                  {currentUser.vpaId ? (
                    <View
                      className="px-2 py-0.5 rounded-full flex-row items-center gap-1 opacity-90"
                      style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    >
                      <Ionicons name="checkmark-circle" size={13} color={colors.cyan} />
                      <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
                        Verified VPA
                      </Text>
                    </View>
                  ) : null}
                </View>
                <Text className="text-sm text-secondary mt-0.5">
                  {currentUser.vpaId ? `VPA: ${currentUser.vpaId}` : 'Tap to set your UPI ID'}
                </Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>

          <TouchableOpacity activeOpacity={0.8} className="card-item">
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="notifications-outline" size={24} color={colors.textSecondary} />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Notifications</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>
        </View>

        {/* App & Theme Section */}
        <View className="gap-3 mt-2">
          <Text className="section-label ml-1 mb-1">APP & THEME</Text>

          <TouchableOpacity
            activeOpacity={0.8}
            className="card-item"
            onPress={() => setThemeModalVisible(true)}
          >
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="color-palette-outline" size={24} color={colors.cyan} />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Theme & Appearance</Text>
                <Text className="text-xs text-secondary mt-0.5">Choose from 4 aesthetic palettes</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>

          <TouchableOpacity activeOpacity={0.8} className="card-item">
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="help-circle-outline" size={24} color={colors.textSecondary} />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Help & Support</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
          </TouchableOpacity>
        </View>

        <TouchableOpacity
          activeOpacity={0.8}
          className="w-full rounded-2xl py-4 mt-4 border border-surface bg-surface items-center shadow-sm"
        >
          <Text className="text-base font-bold text-negative">Log Out</Text>
        </TouchableOpacity>
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
    </View>
  );
}

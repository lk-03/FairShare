import React, { useState } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  TextInput,
  Image,
  ScrollView,
  useColorScheme,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { useExpenseStore } from '../../store/useExpenseStore';
import { useThemeStore, getThemePalette, getActiveThemeClass } from '../../store/useThemeStore';
import { showAlert } from '../../store/useAlertStore';
import { AvatarPickerModal, DIVERSE_CARTOON_AVATARS } from '../AvatarPickerModal';
import { SplitwiseImportModal } from '../SplitwiseImportModal';
import { AppLogo } from '../ui/AppLogo';

interface FirstTimeSetupModalProps {
  initialName?: string;
  initialEmail?: string;
  onFinish: () => void;
}

const COMMON_UPI_HANDLES = ['@okhdfcbank', '@oksbi', '@paytm', '@ybl', '@axl', '@ibl'];

export function FirstTimeSetupModal({
  initialName = '',
  initialEmail = '',
  onFinish,
}: FirstTimeSetupModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const { currentUser, updateUserProfile } = useExpenseStore();

  const [nickname, setNickname] = useState(
    currentUser.nickname || initialName || 'You'
  );
  const [username, setUsername] = useState(
    currentUser.username ||
      (nickname ? nickname.toLowerCase().replace(/[^a-z0-9_]/g, '_') : 'alex_d')
  );
  const [avatarUrl, setAvatarUrl] = useState(
    currentUser.avatarUrl || DIVERSE_CARTOON_AVATARS[0]
  );
  const [vpaId, setVpaId] = useState(currentUser.vpaId || '');
  const [avatarModalVisible, setAvatarModalVisible] = useState(false);
  const [splitwiseModalVisible, setSplitwiseModalVisible] = useState(false);

  const handlePasteVpa = async () => {
    try {
      const text = await Clipboard.getStringAsync();
      if (text && text.includes('@')) {
        setVpaId(text.trim());
      } else {
        showAlert('No UPI ID in Clipboard', 'Clipboard does not contain a valid UPI format (e.g. name@bank).');
      }
    } catch {
      showAlert('Clipboard error', 'Could not read from clipboard.');
    }
  };

  const handleSaveAndStart = async () => {
    if (!nickname.trim()) {
      showAlert('Nickname Required', 'Please enter a display name or nickname.');
      return;
    }

    await updateUserProfile({
      nickname: nickname.trim(),
      fullName: nickname.trim(),
      username: username.trim().replace(/^@/, '') || undefined,
      avatarUrl,
      vpaId: vpaId.trim() || undefined,
      isGuest: false,
    });

    onFinish();
  };

  return (
    <View
      className={`flex-1 justify-between p-6 pt-12 ${activeThemeClass}`}
      style={{ backgroundColor: colors.screen }}
    >
      {/* Header */}
      <View className="flex-row items-center justify-between">
        <View className="flex-row items-center gap-2">
          <AppLogo size={28} withShadow withGlow />
          <Text className="text-lg font-black tracking-tight" style={{ color: colors.textMain }}>
            Customize Profile
          </Text>
        </View>

        <TouchableOpacity
          onPress={onFinish}
          className="px-3 py-1.5 rounded-xl border"
          style={{ backgroundColor: colors.surface, borderColor: colors.border }}
          activeOpacity={0.7}
        >
          <Text className="text-xs font-bold" style={{ color: colors.textSecondary }}>
            Skip for now
          </Text>
        </TouchableOpacity>
      </View>

      <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-5 py-4 my-auto">
        {/* Avatar Picker Widget */}
        <View className="items-center gap-2.5">
          <TouchableOpacity
            onPress={() => setAvatarModalVisible(true)}
            className="relative"
            activeOpacity={0.8}
          >
            <View
              className="w-24 h-24 rounded-full border-2 overflow-hidden shadow-lg"
              style={{
                borderColor: colors.cyan,
                backgroundColor: colors.surface,
              }}
            >
              {avatarUrl ? (
                <Image source={{ uri: avatarUrl }} className="w-full h-full" resizeMode="cover" />
              ) : (
                <View
                  className="w-full h-full items-center justify-center"
                  style={{ backgroundColor: colors.accentPill }}
                >
                  <Text className="text-2xl font-black" style={{ color: colors.cyan }}>
                    {(nickname || 'U').charAt(0).toUpperCase()}
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
          <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
            Tap to change profile picture
          </Text>
        </View>

        {/* Inputs */}
        <View className="gap-3.5 max-w-sm w-full self-center">
          {/* Display Name / Nickname */}
          <View className="gap-1.5">
            <Text
              className="text-[11px] font-black uppercase tracking-wider px-1"
              style={{ color: colors.textSecondary }}
            >
              Nickname / Display Name
            </Text>
            <TextInput
              className="h-12 px-4 rounded-2xl text-sm font-bold border"
              style={{
                backgroundColor: colors.surface,
                borderColor: colors.border,
                color: colors.textMain,
              }}
              placeholder="e.g. Alex"
              placeholderTextColor={colors.textSecondary}
              value={nickname}
              onChangeText={(text) => {
                setNickname(text);
                if (!username || username.startsWith('alex')) {
                  setUsername(text.toLowerCase().replace(/[^a-z0-9_]/g, '_'));
                }
              }}
            />
          </View>

          {/* Username Handle */}
          <View className="gap-1.5">
            <Text
              className="text-[11px] font-black uppercase tracking-wider px-1"
              style={{ color: colors.textSecondary }}
            >
              Username Handle (@)
            </Text>
            <View
              className="flex-row items-center h-12 px-4 rounded-2xl border"
              style={{
                backgroundColor: colors.surface,
                borderColor: colors.border,
              }}
            >
              <Text className="text-sm font-bold mr-1" style={{ color: colors.cyan }}>
                @
              </Text>
              <TextInput
                className="flex-1 text-sm font-bold"
                style={{ color: colors.textMain }}
                placeholder="alex_d"
                placeholderTextColor={colors.textSecondary}
                autoCapitalize="none"
                value={username}
                onChangeText={(t) => setUsername(t.toLowerCase().replace(/[^a-z0-9_]/g, ''))}
              />
            </View>
          </View>

          {/* UPI ID (Optional) */}
          <View className="gap-1.5">
            <View className="flex-row items-center justify-between px-1">
              <Text
                className="text-[11px] font-black uppercase tracking-wider"
                style={{ color: colors.textSecondary }}
              >
                UPI ID (For Instant Settlements)
              </Text>
              <TouchableOpacity onPress={handlePasteVpa} activeOpacity={0.7}>
                <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                  Paste Clipboard
                </Text>
              </TouchableOpacity>
            </View>
            <TextInput
              className="h-12 px-4 rounded-2xl text-sm font-bold border"
              style={{
                backgroundColor: colors.surface,
                borderColor: colors.border,
                color: colors.textMain,
              }}
              placeholder="name@okaxis"
              placeholderTextColor={colors.textSecondary}
              autoCapitalize="none"
              value={vpaId}
              onChangeText={setVpaId}
            />

            {/* Common UPI handle chips */}
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-1.5 py-1">
              {COMMON_UPI_HANDLES.map((handle) => (
                <TouchableOpacity
                  key={handle}
                  onPress={() => {
                    const prefix = vpaId.split('@')[0] || nickname.toLowerCase().replace(/[^a-z0-9]/g, '');
                    setVpaId(`${prefix}${handle}`);
                  }}
                  className="px-2.5 py-1 rounded-xl border"
                  style={{
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                  }}
                  activeOpacity={0.7}
                >
                  <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
                    {handle}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>
          </View>

          {/* Splitwise Migration Callout Card */}
          <TouchableOpacity
            onPress={() => setSplitwiseModalVisible(true)}
            className="p-3.5 rounded-2xl flex-row items-center justify-between border shadow-sm"
            style={{
              backgroundColor: colors.surface,
              borderColor: colors.emerald,
            }}
            activeOpacity={0.75}
          >
            <View className="flex-row items-center gap-2.5 flex-1 pr-2">
              <View
                className="w-9 h-9 rounded-xl items-center justify-center"
                style={{ backgroundColor: `${colors.emerald}20` }}
              >
                <Ionicons name="swap-horizontal" size={18} color={colors.emerald} />
              </View>
              <View className="flex-1">
                <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                  Migrating from Splitwise?
                </Text>
                <Text className="text-[11px] font-semibold" style={{ color: colors.emerald }}>
                  1-Tap Import export.csv
                </Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={16} color={colors.emerald} />
          </TouchableOpacity>
        </View>
      </ScrollView>

      {/* Action CTA */}
      <TouchableOpacity
        onPress={handleSaveAndStart}
        className="h-14 rounded-2xl items-center justify-center shadow-lg mt-2"
        style={{ backgroundColor: colors.cyan }}
        activeOpacity={0.85}
      >
        <Text className="text-base font-black text-slate-900">
          Complete Setup & Start
        </Text>
      </TouchableOpacity>

      {/* Nested Modals */}
      <AvatarPickerModal
        visible={avatarModalVisible}
        onClose={() => setAvatarModalVisible(false)}
        onSelectAvatar={(url: string) => {
          setAvatarUrl(url);
          setAvatarModalVisible(false);
        }}
      />

      <SplitwiseImportModal
        visible={splitwiseModalVisible}
        onClose={() => setSplitwiseModalVisible(false)}
        onSuccess={() => {
          setSplitwiseModalVisible(false);
          onFinish();
        }}
      />
    </View>
  );
}

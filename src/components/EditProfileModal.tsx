import React, { useState, useEffect } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  StatusBar,
  useColorScheme,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { AvatarPickerModal } from '@/components/AvatarPickerModal';
import { Text } from '@/components/ui/Text';

interface EditProfileModalProps {
  visible: boolean;
  onClose: () => void;
}

const USERNAME_REGEX = /^[a-zA-Z0-9_]{3,24}$/;

export function EditProfileModal({ visible, onClose }: EditProfileModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { currentUser, updateUserProfile } = useExpenseStore();

  const [fullName, setFullName] = useState(currentUser.fullName || '');
  const [nickname, setNickname] = useState(currentUser.nickname || '');
  const [username, setUsername] = useState(currentUser.username || '');
  const [avatarPickerVisible, setAvatarPickerVisible] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (visible) {
      setFullName(currentUser.fullName || '');
      setNickname(currentUser.nickname || '');
      setUsername(currentUser.username || '');
    }
  }, [visible, currentUser]);

  const sanitizedUsername = username.trim().toLowerCase().replace(/^@/, '');
  const isValidUsername = !sanitizedUsername || USERNAME_REGEX.test(sanitizedUsername);

  const handleSave = async () => {
    if (!fullName.trim()) {
      showAlert('Required Field', 'Please enter your Full Name.');
      return;
    }

    if (sanitizedUsername && !USERNAME_REGEX.test(sanitizedUsername)) {
      showAlert(
        'Invalid Username',
        'Username must be between 3 and 24 characters and only contain letters, numbers, and underscores.'
      );
      return;
    }

    setIsSaving(true);
    try {
      await updateUserProfile({
        fullName: fullName.trim(),
        nickname: nickname.trim() || fullName.trim(),
        username: sanitizedUsername || undefined,
      });
      onClose();
    } catch (err) {
      showAlert('Save Failed', 'Could not update profile. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  const displayName = nickname || fullName || 'You';

  return (
    <Modal visible={visible} animationType="slide" transparent={false} onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass}`} style={{ backgroundColor: colors.screen }}>
        <SafeAreaView className="flex-1" edges={['top', 'bottom']}>
          <StatusBar barStyle={isDark ? 'light-content' : 'dark-content'} />

          {/* Top Bar Header */}
          <View
            className="flex-row items-center justify-between px-4 py-3.5"
            style={{ backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border }}
          >
            <TouchableOpacity onPress={onClose} className="p-2 rounded-xl" activeOpacity={0.7}>
              <Ionicons name="arrow-back" size={24} color={colors.textSecondary} />
            </TouchableOpacity>
            <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
              Edit Profile
            </Text>
            <View className="w-8" />
          </View>

          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerClassName="p-6 gap-6"
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="none"
          >
            {/* Avatar Row with Change Photo Trigger */}
            <View
              className="p-5 rounded-3xl flex-row items-center justify-between"
              style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
            >
              <View className="flex-row items-center gap-4 flex-1">
                <View
                  className="w-16 h-16 rounded-full items-center justify-center overflow-hidden"
                  style={{
                    backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
                    borderWidth: 1.5,
                    borderColor: colors.border,
                  }}
                >
                  {currentUser.avatarUrl ? (
                    <Image source={{ uri: currentUser.avatarUrl }} className="w-16 h-16 rounded-full" />
                  ) : (
                    <Text className="text-2xl font-extrabold" style={{ color: colors.textMain }}>
                      {displayName.charAt(0).toUpperCase()}
                    </Text>
                  )}
                </View>
                <View className="flex-1">
                  <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                    Profile Photo
                  </Text>
                  <Text className="text-xs" style={{ color: colors.textSecondary }}>
                    Cartoon avatar or camera picture
                  </Text>
                </View>
              </View>

              <TouchableOpacity
                className="px-3.5 py-2 rounded-xl shadow-sm"
                style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                onPress={() => setAvatarPickerVisible(true)}
                activeOpacity={0.7}
              >
                <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                  Change
                </Text>
              </TouchableOpacity>
            </View>

            {/* Profile Fields Section */}
            <View className="gap-4">
              {/* Nickname (Primary Display Name) */}
              <View className="gap-1.5">
                <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                  NICKNAME (PRIMARY DISPLAY NAME)
                </Text>
                <View
                  className="flex-row items-center px-4 rounded-2xl gap-3"
                  style={{
                    backgroundColor: colors.surface,
                    borderWidth: 1,
                    borderColor: colors.border,
                    minHeight: 52,
                    height: 52,
                  }}
                >
                  <Ionicons name="happy-outline" size={20} color={colors.cyan} />
                  <TextInput
                    className="flex-1 text-base font-bold"
                    style={{ color: colors.textMain, textAlignVertical: 'center' }}
                    placeholder="e.g. Sam, Rahul"
                    placeholderTextColor={colors.textSecondary}
                    value={nickname}
                    onChangeText={setNickname}
                    autoCorrect={false}
                    multiline={false}
                    scrollEnabled={false}
                  />
                </View>
                <Text className="text-[11px] px-1" style={{ color: colors.textSecondary }}>
                  This will be shown prominently in your groups, debts, and expense splits.
                </Text>
              </View>

              {/* Username Handle */}
              <View className="gap-1.5">
                <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                  USERNAME HANDLE (@TAG)
                </Text>
                <View
                  className="flex-row items-center px-4 rounded-2xl gap-2"
                  style={{
                    backgroundColor: colors.surface,
                    borderWidth: 1,
                    borderColor: isValidUsername ? colors.border : colors.red,
                    minHeight: 52,
                    height: 52,
                  }}
                >
                  <Text className="text-base font-bold" style={{ color: colors.cyan }}>
                    @
                  </Text>
                  <TextInput
                    className="flex-1 text-base font-bold"
                    style={{ color: colors.textMain, textAlignVertical: 'center' }}
                    placeholder="username"
                    placeholderTextColor={colors.textSecondary}
                    autoCapitalize="none"
                    autoCorrect={false}
                    value={username}
                    onChangeText={setUsername}
                    multiline={false}
                    scrollEnabled={false}
                  />
                  {sanitizedUsername && isValidUsername && (
                    <Ionicons name="checkmark-circle" size={18} color={colors.cyan} />
                  )}
                </View>
                <Text className="text-[11px] px-1" style={{ color: colors.textSecondary }}>
                  Friends can mention you in comments with @{sanitizedUsername || 'username'}.
                </Text>
              </View>

              {/* Full Name */}
              <View className="gap-1.5">
                <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                  FULL LEGAL NAME
                </Text>
                <View
                  className="flex-row items-center px-4 rounded-2xl gap-3"
                  style={{
                    backgroundColor: colors.surface,
                    borderWidth: 1,
                    borderColor: colors.border,
                    minHeight: 52,
                    height: 52,
                  }}
                >
                  <Ionicons name="person-outline" size={20} color={colors.textSecondary} />
                  <TextInput
                    className="flex-1 text-base font-bold"
                    style={{ color: colors.textMain, textAlignVertical: 'center' }}
                    placeholder="Your Full Name"
                    placeholderTextColor={colors.textSecondary}
                    value={fullName}
                    onChangeText={setFullName}
                    multiline={false}
                    scrollEnabled={false}
                  />
                </View>
              </View>
            </View>

            {/* Save Button */}
            <TouchableOpacity
              className="py-4 rounded-2xl items-center justify-center shadow-sm mt-2"
              style={{ backgroundColor: colors.cyan }}
              onPress={handleSave}
              disabled={isSaving}
              activeOpacity={0.85}
            >
              <Text className="text-base font-extrabold" style={{ color: '#0F172A' }}>
                {isSaving ? 'Saving...' : 'Save Profile Changes'}
              </Text>
            </TouchableOpacity>
          </ScrollView>

          {/* Quick Avatar Picker Modal */}
          <AvatarPickerModal
            visible={avatarPickerVisible}
            onClose={() => setAvatarPickerVisible(false)}
          />
        </SafeAreaView>
      </View>
    </Modal>
  );
}

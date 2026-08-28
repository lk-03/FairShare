import React, { useState } from 'react';
import {
  View,
  Modal,
  TouchableOpacity,
  ScrollView,
  Image,
  StatusBar,
  useColorScheme,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { Text } from '@/components/ui/Text';

interface AvatarPickerModalProps {
  visible: boolean;
  onClose: () => void;
}

// 10 Curated copyright-free (CC0/MIT) diverse cartoon illustrated avatars via DiceBear
export const DIVERSE_CARTOON_AVATARS = [
  'https://api.dicebear.com/7.x/bottts-neutral/png?seed=Felix&backgroundColor=b6e3f4',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Aria&backgroundColor=ffd5dc',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Zane&backgroundColor=d1d4f9',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Nala&backgroundColor=c0aede',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Kiran&backgroundColor=ffdfbf',
  'https://api.dicebear.com/7.x/bottts-neutral/png?seed=Milo&backgroundColor=ffd5dc',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Tara&backgroundColor=b6e3f4',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Leo&backgroundColor=ffdfbf',
  'https://api.dicebear.com/7.x/adventurer/png?seed=Sam&backgroundColor=d1d4f9',
  'https://api.dicebear.com/7.x/bottts-neutral/png?seed=Cleo&backgroundColor=c0aede',
];

export function AvatarPickerModal({ visible, onClose }: AvatarPickerModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { currentUser, updateUserProfile } = useExpenseStore();
  const [selectedAvatar, setSelectedAvatar] = useState<string | undefined>(currentUser.avatarUrl);
  const [isSaving, setIsSaving] = useState(false);

  const handlePickFromLibrary = async () => {
    try {
      const permissionResult = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permissionResult.granted) {
        showAlert('Permission Required', 'Please allow photo library access to choose a profile picture.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.85,
      });

      if (!result.canceled && result.assets && result.assets[0]?.uri) {
        const uri = result.assets[0].uri;
        setSelectedAvatar(uri);
        await updateUserProfile({ avatarUrl: uri });
        onClose();
      }
    } catch (e) {
      console.warn('Image picker error:', e);
    }
  };

  const handleTakePhoto = async () => {
    try {
      const permissionResult = await ImagePicker.requestCameraPermissionsAsync();
      if (!permissionResult.granted) {
        showAlert('Permission Required', 'Please allow camera access to take a profile picture.');
        return;
      }

      const result = await ImagePicker.launchCameraAsync({
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.85,
      });

      if (!result.canceled && result.assets && result.assets[0]?.uri) {
        const uri = result.assets[0].uri;
        setSelectedAvatar(uri);
        await updateUserProfile({ avatarUrl: uri });
        onClose();
      }
    } catch (e) {
      console.warn('Camera error:', e);
    }
  };

  const handleSelectPreset = async (avatarUrl: string) => {
    setSelectedAvatar(avatarUrl);
    setIsSaving(true);
    try {
      await updateUserProfile({ avatarUrl });
      onClose();
    } catch (err) {
      showAlert('Update Failed', 'Could not update avatar.');
    } finally {
      setIsSaving(false);
    }
  };

  const handleRemovePhoto = async () => {
    setSelectedAvatar(undefined);
    await updateUserProfile({ avatarUrl: undefined });
    onClose();
  };

  const displayName = currentUser.nickname || currentUser.fullName;

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
              <Ionicons name="close" size={24} color={colors.textSecondary} />
            </TouchableOpacity>
            <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
              Choose Avatar
            </Text>
            <View className="w-8" />
          </View>

          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerClassName="p-6 gap-6"
          >
            {/* Current Avatar Preview */}
            <View
              className="p-6 rounded-3xl items-center gap-4"
              style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
            >
              <View
                className="w-28 h-28 rounded-full items-center justify-center overflow-hidden"
                style={{
                  backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
                  borderWidth: 2,
                  borderColor: colors.border,
                }}
              >
                {selectedAvatar ? (
                  <Image source={{ uri: selectedAvatar }} className="w-28 h-28 rounded-full" />
                ) : (
                  <Text className="text-4xl font-extrabold" style={{ color: colors.textMain }}>
                    {displayName.charAt(0).toUpperCase()}
                  </Text>
                )}
              </View>

              {/* Upload or Camera Buttons */}
              <View className="flex-row gap-3">
                <TouchableOpacity
                  className="flex-row items-center gap-1.5 px-4 py-2.5 rounded-xl shadow-sm"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                  onPress={handlePickFromLibrary}
                  activeOpacity={0.7}
                >
                  <Ionicons name="images-outline" size={16} color={colors.cyan} />
                  <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                    Photo Library
                  </Text>
                </TouchableOpacity>

                <TouchableOpacity
                  className="flex-row items-center gap-1.5 px-4 py-2.5 rounded-xl shadow-sm"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                  onPress={handleTakePhoto}
                  activeOpacity={0.7}
                >
                  <Ionicons name="camera-outline" size={16} color={colors.cyan} />
                  <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                    Camera
                  </Text>
                </TouchableOpacity>

                {selectedAvatar && (
                  <TouchableOpacity
                    className="p-2.5 rounded-xl items-center justify-center"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={handleRemovePhoto}
                    activeOpacity={0.7}
                  >
                    <Ionicons name="trash-outline" size={16} color={colors.red} />
                  </TouchableOpacity>
                )}
              </View>
            </View>

            {/* Diverse Cartoon Avatars Grid */}
            <View className="gap-3">
              <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                DIVERSE CARTOON AVATARS (COPYRIGHT-FREE)
              </Text>

              <View className="flex-row flex-wrap gap-4 justify-between">
                {DIVERSE_CARTOON_AVATARS.map((url, idx) => {
                  const isSelected = selectedAvatar === url;
                  return (
                    <TouchableOpacity
                      key={idx}
                      className="w-16 h-16 rounded-2xl overflow-hidden items-center justify-center shadow-sm"
                      style={{
                        borderWidth: isSelected ? 3 : 1,
                        borderColor: isSelected ? colors.cyan : colors.border,
                        backgroundColor: colors.surface,
                      }}
                      onPress={() => handleSelectPreset(url)}
                      activeOpacity={0.75}
                      disabled={isSaving}
                    >
                      <Image source={{ uri: url }} className="w-14 h-14" />
                    </TouchableOpacity>
                  );
                })}
              </View>
            </View>
          </ScrollView>
        </SafeAreaView>
      </View>
    </Modal>
  );
}

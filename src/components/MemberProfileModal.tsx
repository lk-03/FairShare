import React, { useState } from 'react';
import {
  View,
  Modal,
  TouchableOpacity,
  ScrollView,
  Image,
  useColorScheme,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { GroupMember, UserProfile } from '@/types';
import { launchUPIIntent } from '@/services/payment/upiIntent';
import { Text } from '@/components/ui/Text';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

interface MemberProfileModalProps {
  visible: boolean;
  onClose: () => void;
  member?: GroupMember | null;
  profile?: UserProfile | null;
}

export function MemberProfileModal({
  visible,
  onClose,
  member,
  profile: directProfile,
}: MemberProfileModalProps) {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const insets = useSafeAreaInsets();
  const { currentUser } = useExpenseStore();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const [copied, setCopied] = useState(false);

  const user = member?.profile || directProfile || (member?.userId === currentUser.id ? currentUser : null);
  if (!user) return null;

  const isSelf = user.id === currentUser.id || member?.userId === currentUser.id;
  const displayName = isSelf ? (user.nickname || user.fullName || 'You') : (user.nickname || user.fullName || 'Member');
  const username = user.username;
  const hasVpa = !!user.vpaId;

  const handleCopyVpa = async () => {
    if (!user.vpaId) return;
    await Clipboard.setStringAsync(user.vpaId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handlePayViaUPI = async () => {
    if (!user.vpaId) return;
    const success = await launchUPIIntent({
      vpaId: user.vpaId,
      payeeName: displayName,
      amount: 1, // Minimum prompt amount for quick transfer intent
      currency: 'INR',
      note: `Payment to ${displayName}`,
    });

    if (!success) {
      showAlert(
        'UPI App Not Found',
        `Could not open UPI app automatically. You can copy the UPI ID (${user.vpaId}) and transfer in your banking app.`
      );
    }
  };

  return (
    <Modal
      visible={visible}
      animationType="fade"
      transparent
      statusBarTranslucent={true}
      onRequestClose={onClose}
    >
      <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end sm:justify-center p-0 sm:p-6`}>
        <TouchableOpacity className="flex-1" activeOpacity={1} onPress={onClose} />

        <View
          className="rounded-t-[36px] sm:rounded-[32px] p-6 gap-5 shadow-2xl"
          style={{
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
            maxHeight: '85%',
            paddingBottom: Math.max(insets.bottom + 12, 28),
          }}
        >
          {/* Header Close Button */}
          <View className="flex-row items-center justify-between">
            <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
              {isSelf ? 'YOUR PROFILE' : 'MEMBER PROFILE'}
            </Text>
            <TouchableOpacity onPress={onClose} className="p-1 rounded-xl" activeOpacity={0.7}>
              <Ionicons name="close" size={22} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="items-center gap-4 pb-2">
            {/* Avatar Circle */}
            <View
              className="w-24 h-24 rounded-full items-center justify-center overflow-hidden"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
                borderWidth: 2,
                borderColor: colors.border,
              }}
            >
              {user.avatarUrl ? (
                <Image source={{ uri: user.avatarUrl }} className="w-24 h-24 rounded-full" />
              ) : (
                <Text className="text-4xl font-extrabold" style={{ color: colors.textMain }}>
                  {displayName.charAt(0).toUpperCase()}
                </Text>
              )}
            </View>

            {/* Name & Handle Details */}
            <View className="items-center gap-1">
              <View className="flex-row items-center gap-1.5 justify-center">
                <Text className="text-2xl font-extrabold text-center" style={{ color: colors.textMain }}>
                  {displayName}
                </Text>
                {hasVpa && (
                  <Ionicons name="checkmark-circle" size={20} color={colors.cyan} />
                )}
              </View>

              {hasVpa && (
                <Text className="text-xs font-semibold text-center" style={{ color: colors.cyan }}>
                  Verified UPI
                </Text>
              )}

              {username && (
                <Text className="text-sm font-bold text-center mt-0.5" style={{ color: colors.textSecondary }}>
                  @{username}
                </Text>
              )}

              {member?.role && (
                <View
                  className="px-2.5 py-0.5 rounded-full mt-1.5"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                >
                  <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
                    {member.role}
                  </Text>
                </View>
              )}
            </View>

            {/* Payment & UPI Card */}
            <View
              className="w-full p-4 rounded-2xl gap-3 mt-2"
              style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
            >
              <View className="flex-row items-center justify-between">
                <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                  PAYMENT & UPI
                </Text>
                {hasVpa && (
                  <View className="flex-row items-center gap-1">
                    <Ionicons name="shield-checkmark" size={13} color={colors.cyan} />
                    <Text className="text-[11px] font-bold" style={{ color: colors.cyan }}>
                      Verified
                    </Text>
                  </View>
                )}
              </View>

              {hasVpa ? (
                <View className="gap-3">
                  <View className="flex-row items-center justify-between bg-surface p-3 rounded-xl border border-surface">
                    <View className="flex-1 pr-2">
                      <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                        UPI Virtual Payment Address
                      </Text>
                      <Text className="text-sm font-bold mt-0.5" style={{ color: colors.textMain }}>
                        {user.vpaId}
                      </Text>
                    </View>
                    <TouchableOpacity
                      className="px-3 py-1.5 rounded-lg flex-row items-center gap-1"
                      style={{ backgroundColor: colors.accentPill }}
                      onPress={handleCopyVpa}
                      activeOpacity={0.7}
                    >
                      <Ionicons
                        name={copied ? 'checkmark' : 'copy-outline'}
                        size={14}
                        color={copied ? colors.cyan : colors.textSecondary}
                      />
                      <Text
                        className="text-xs font-bold"
                        style={{ color: copied ? colors.cyan : colors.textSecondary }}
                      >
                        {copied ? 'Copied' : 'Copy'}
                      </Text>
                    </TouchableOpacity>
                  </View>

                  {isSelf ? (
                    <TouchableOpacity
                      className="py-3 rounded-xl items-center justify-center flex-row gap-2 shadow-sm"
                      style={{ backgroundColor: colors.cyan }}
                      onPress={() => {
                        onClose();
                        router.push('/(tabs)/profile');
                      }}
                      activeOpacity={0.85}
                    >
                      <Ionicons name="pencil" size={16} color="#0F172A" />
                      <Text className="text-sm font-extrabold" style={{ color: '#0F172A' }}>
                        Edit Your Profile in Settings
                      </Text>
                    </TouchableOpacity>
                  ) : (
                    <TouchableOpacity
                      className="py-3 rounded-xl items-center justify-center flex-row gap-2 shadow-sm"
                      style={{ backgroundColor: colors.cyan }}
                      onPress={handlePayViaUPI}
                      activeOpacity={0.85}
                    >
                      <Ionicons name="card-outline" size={16} color="#0F172A" />
                      <Text className="text-sm font-extrabold" style={{ color: '#0F172A' }}>
                        Pay {displayName} via UPI
                      </Text>
                    </TouchableOpacity>
                  )}
                </View>
              ) : isSelf ? (
                <View className="py-2 items-center gap-2">
                  <Text className="text-xs italic text-center" style={{ color: colors.textSecondary }}>
                    You haven't added a UPI ID yet.
                  </Text>
                  <TouchableOpacity
                    className="px-4 py-2.5 rounded-xl flex-row items-center gap-1.5"
                    style={{ backgroundColor: colors.cyan }}
                    onPress={() => {
                      onClose();
                      router.push('/(tabs)/profile');
                    }}
                    activeOpacity={0.85}
                  >
                    <Ionicons name="add-circle-outline" size={16} color="#0F172A" />
                    <Text className="text-xs font-bold" style={{ color: '#0F172A' }}>
                      Add UPI ID in Profile
                    </Text>
                  </TouchableOpacity>
                </View>
              ) : (
                <View className="py-2 items-center">
                  <Text className="text-xs italic" style={{ color: colors.textSecondary }}>
                    UPI ID not configured by this member.
                  </Text>
                </View>
              )}
            </View>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

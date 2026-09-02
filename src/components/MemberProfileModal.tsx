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
import { GroupMember, UserProfile, EventCohort } from '@/types';
import { launchUPIIntent } from '@/services/payment/upiIntent';
import { Text } from '@/components/ui/Text';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

interface MemberProfileModalProps {
  visible: boolean;
  onClose: () => void;
  member?: GroupMember | null;
  profile?: UserProfile | null;
  cohortId?: string;
  cohort?: EventCohort | null;
}

export function MemberProfileModal({
  visible,
  onClose,
  member,
  profile: directProfile,
  cohortId,
  cohort,
}: MemberProfileModalProps) {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const insets = useSafeAreaInsets();
  const { currentUser, members, kickMember, leaveCohort } = useExpenseStore();
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

  const cohortMembers = cohortId ? members[cohortId] || [] : [];
  const currentMember = cohortMembers.find((m) => m.userId === currentUser.id);
  const isCurrentAdmin = currentMember?.role === 'admin' || cohort?.createdBy === currentUser.id;

  const handleKickMember = () => {
    if (!cohortId) return;
    showAlert(
      `Remove ${displayName}?`,
      `Are you sure you want to remove ${displayName} from "${cohort?.name || 'this group'}"? They will no longer have access to this ledger.`,
      [
        {
          text: 'Remove Member',
          style: 'destructive',
          onPress: async () => {
            await kickMember(cohortId, user.id);
            onClose();
            showAlert('Member Removed', `${displayName} has been removed from the group.`);
          },
        },
        { text: 'Cancel', style: 'cancel' },
      ]
    );
  };

  const handleLeaveGroup = () => {
    if (!cohortId) return;
    const remaining = cohortMembers.filter(
      (m) => m.userId !== currentUser.id && !m.isPlaceholder
    );
    remaining.sort((a, b) => new Date(a.joinedAt).getTime() - new Date(b.joinedAt).getTime());
    const nextAdminName =
      remaining[0]?.profile?.fullName || remaining[0]?.profile?.nickname || 'the next oldest member';

    const message = isCurrentAdmin
      ? remaining.length > 0
        ? `Since you are the group admin, leaving will automatically assign admin privileges to ${nextAdminName} and notify all group members. Are you sure you want to leave "${cohort?.name || 'this group'}"?`
        : `You are the only member in this group. Leaving will archive and schedule "${cohort?.name || 'this group'}" for deletion in 15 days.`
      : `Are you sure you want to leave "${cohort?.name || 'this group'}"?`;

    showAlert('Leave Group', message, [
      {
        text: 'Leave Group',
        style: 'destructive',
        onPress: async () => {
          const res = await leaveCohort(cohortId);
          onClose();
          router.replace('/(tabs)/groups' as any);
          if (res.nextAdminName) {
            showAlert('Group Left', `You left the group. Admin transferred to ${res.nextAdminName}.`);
          } else {
            showAlert('Group Left', `You have left "${cohort?.name || 'the group'}".`);
          }
        },
      },
      { text: 'Cancel', style: 'cancel' },
    ]);
  };

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

            {/* Admin Management Actions: Kick Member */}
            {!isSelf && isCurrentAdmin && cohortId && (
              <TouchableOpacity
                className="w-full py-3.5 rounded-2xl items-center justify-center flex-row gap-2 border shadow-sm mt-1"
                style={{
                  backgroundColor: 'rgba(251, 113, 133, 0.1)',
                  borderColor: 'rgba(251, 113, 133, 0.3)',
                }}
                onPress={handleKickMember}
                activeOpacity={0.8}
              >
                <Ionicons name="person-remove-outline" size={17} color="#FB7185" />
                <Text className="text-rose-400 font-bold text-sm">
                  Remove Member from Group
                </Text>
              </TouchableOpacity>
            )}

            {/* Leave Group Action for Self (Only available in multi-member groups; 1-member groups can only be deleted) */}
            {isSelf && cohortId && cohortMembers.filter((m) => !m.isPlaceholder).length > 1 && (
              <TouchableOpacity
                className="w-full py-3.5 rounded-2xl items-center justify-center flex-row gap-2 border shadow-sm mt-1"
                style={{
                  backgroundColor: 'rgba(251, 113, 133, 0.1)',
                  borderColor: 'rgba(251, 113, 133, 0.3)',
                }}
                onPress={handleLeaveGroup}
                activeOpacity={0.8}
              >
                <Ionicons name="log-out-outline" size={18} color="#FB7185" />
                <Text className="text-rose-400 font-bold text-sm">
                  Leave Group
                </Text>
              </TouchableOpacity>
            )}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

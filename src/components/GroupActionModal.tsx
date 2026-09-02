import React from 'react';
import { View, TouchableOpacity, Modal, useColorScheme, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { EventCohort } from '@/types';
import { Text } from '@/components/ui/Text';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

interface GroupActionModalProps {
  visible: boolean;
  onClose: () => void;
  cohort: EventCohort | null;
  onInvite?: () => void;
  onEdit?: () => void;
}

export function GroupActionModal({
  visible,
  onClose,
  cohort,
  onInvite,
  onEdit,
}: GroupActionModalProps) {
  const systemScheme = useColorScheme();
  const insets = useSafeAreaInsets();
  const { currentUser, members, toggleArchiveCohort, deleteCohort } = useExpenseStore();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  if (!cohort) return null;

  const cohortMembers = members[cohort.id] || [];
  const isCurrentAdmin =
    cohort.createdBy === currentUser.id ||
    cohortMembers.some((m) => m.userId === currentUser.id && m.role === 'admin');

  const handleToggleArchive = async () => {
    const nextArchived = !cohort.isArchived;
    await toggleArchiveCohort(cohort.id);
    onClose();
    if (nextArchived) {
      showAlert(
        'Group Archived',
        `"${cohort.name}" is now archived. Its balance will no longer count towards your total owings, but the group remains accessible.`
      );
    } else {
      showAlert(
        'Group Unarchived',
        `"${cohort.name}" is now unarchived and included in your total owings.`
      );
    }
  };

  const handleDeleteGroup = () => {
    showAlert(
      'Delete Group',
      `Are you sure you want to delete "${cohort.name}"?\n\nThis group will be moved to Trash for 15 days, after which it will be permanently deleted from the database. You can restore it anytime within 15 days.`,
      [
        {
          text: 'Delete Group (15 Days Trash)',
          style: 'destructive',
          onPress: async () => {
            onClose();
            await deleteCohort(cohort.id);
            showAlert(
              'Group Moved to Trash',
              `"${cohort.name}" has been moved to Trash and will be permanently deleted in 15 days.`
            );
          },
        },
        { text: 'Cancel', style: 'cancel' },
      ]
    );
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
          {/* Header */}
          <View className="flex-row items-center justify-between">
            <View className="flex-row items-center gap-3 flex-1 pr-2">
              <CategoryIcon
                category={cohort.category}
                customIcon={cohort.customIcon}
                size={42}
                variant="solid"
              />
              <View className="flex-1">
                <Text className="text-xl font-extrabold" style={{ color: colors.textMain }} numberOfLines={1}>
                  {cohort.name}
                </Text>
                <View className="flex-row items-center gap-2 mt-0.5">
                  <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                    Code: {cohort.inviteCode}
                  </Text>
                  {cohort.isArchived && (
                    <View
                      className="px-2 py-0.5 rounded-full"
                      style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    >
                      <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
                        Archived (Muted)
                      </Text>
                    </View>
                  )}
                </View>
              </View>
            </View>

            <TouchableOpacity onPress={onClose} className="p-1 rounded-xl" activeOpacity={0.7}>
              <Ionicons name="close" size={22} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>

          {/* Action List */}
          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-2.5 pt-1 pb-1">
            {/* 1. Invite Action */}
            <TouchableOpacity
              className="p-4 rounded-2xl flex-row items-center gap-3.5 border"
              style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
              onPress={() => {
                onClose();
                onInvite?.();
              }}
              activeOpacity={0.75}
            >
              <View
                className="w-10 h-10 rounded-xl items-center justify-center"
                style={{ backgroundColor: 'rgba(32, 138, 239, 0.15)' }}
              >
                <Ionicons name="qr-code-outline" size={20} color={colors.cyan} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                  Invite Members
                </Text>
                <Text className="text-xs mt-0.5" style={{ color: colors.textSecondary }}>
                  Share QR code or copy invite code ({cohort.inviteCode})
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} />
            </TouchableOpacity>

            {/* 2. Edit Action */}
            {isCurrentAdmin && (
              <TouchableOpacity
                className="p-4 rounded-2xl flex-row items-center gap-3.5 border"
                style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                onPress={() => {
                  onClose();
                  onEdit?.();
                }}
                activeOpacity={0.75}
              >
                <View
                  className="w-10 h-10 rounded-xl items-center justify-center"
                  style={{ backgroundColor: 'rgba(16, 185, 129, 0.15)' }}
                >
                  <Ionicons name="create-outline" size={20} color="#10B981" />
                </View>
                <View className="flex-1">
                  <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                    Edit Group
                  </Text>
                  <Text className="text-xs mt-0.5" style={{ color: colors.textSecondary }}>
                    Change name, icon, category, or description
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} />
              </TouchableOpacity>
            )}

            {/* 3. Archive / Unarchive Action */}
            <TouchableOpacity
              className="p-4 rounded-2xl flex-row items-center gap-3.5 border"
              style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
              onPress={handleToggleArchive}
              activeOpacity={0.75}
            >
              <View
                className="w-10 h-10 rounded-xl items-center justify-center"
                style={{ backgroundColor: 'rgba(245, 158, 11, 0.15)' }}
              >
                <Ionicons
                  name={cohort.isArchived ? 'archive' : 'archive-outline'}
                  size={20}
                  color="#F59E0B"
                />
              </View>
              <View className="flex-1">
                <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                  {cohort.isArchived ? 'Unarchive Group' : 'Archive Group'}
                </Text>
                <Text className="text-xs mt-0.5" style={{ color: colors.textSecondary }}>
                  {cohort.isArchived
                    ? 'Include group balance back into your total owings'
                    : 'Stop including in total owings (never auto-deletes)'}
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={18} color={colors.textSecondary} />
            </TouchableOpacity>

            {/* 4. Delete Group Action */}
            {isCurrentAdmin && (
              <TouchableOpacity
                className="p-4 rounded-2xl flex-row items-center gap-3.5 border mt-1"
                style={{
                  backgroundColor: 'rgba(251, 113, 133, 0.08)',
                  borderColor: 'rgba(251, 113, 133, 0.25)',
                }}
                onPress={handleDeleteGroup}
                activeOpacity={0.75}
              >
                <View
                  className="w-10 h-10 rounded-xl items-center justify-center"
                  style={{ backgroundColor: 'rgba(251, 113, 133, 0.15)' }}
                >
                  <Ionicons name="trash-outline" size={20} color="#FB7185" />
                </View>
                <View className="flex-1">
                  <Text className="text-base font-bold text-rose-400">
                    Delete Group
                  </Text>
                  <Text className="text-xs text-rose-400/80 mt-0.5">
                    Move to Trash for 15 days before permanent database deletion
                  </Text>
                </View>
                <Ionicons name="chevron-forward" size={18} color="#FB7185" />
              </TouchableOpacity>
            )}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

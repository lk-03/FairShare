import React, { useState } from 'react';
import { View, ScrollView, TouchableOpacity, Platform, useColorScheme } from 'react-native';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { CreateGroupModal } from '@/components/CreateGroupModal';
import { JoinGroupModal } from '@/components/JoinGroupModal';
import { GroupActionModal } from '@/components/GroupActionModal';
import { QRCodeModal } from '@/components/QRCodeModal';
import { EditGroupModal } from '@/components/EditGroupModal';
import { EventCohort } from '@/types';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

export default function GroupsScreen() {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [joinGroupVisible, setJoinGroupVisible] = useState(false);
  const [fabOpen, setFabOpen] = useState(false);
  const [archivedExpanded, setArchivedExpanded] = useState(false);
  const [longPressedCohort, setLongPressedCohort] = useState<EventCohort | null>(null);
  const [groupActionVisible, setGroupActionVisible] = useState(false);
  const [qrCodeModalVisible, setQrCodeModalVisible] = useState(false);
  const [editGroupModalVisible, setEditGroupModalVisible] = useState(false);

  const {
    cohorts,
    members,
    expenses,
    currentUser,
    restoreDeletedCohort,
    deleteCohortPermanently,
  } = useExpenseStore();

  const activeCohorts = cohorts.filter((c) => !c.isDeleted);
  const deletedCohorts = cohorts.filter((c) => !!c.isDeleted);

  const fabBottom = Platform.select({ ios: 28, android: 20 }) ?? 20;

  return (
    <View className="flex-1 bg-screen pt-safe relative">
      {/* Screen Header */}
      <View className="screen-header">
        <Text className="screen-title text-main">Groups</Text>
      </View>

      <ScrollView
        contentContainerClassName="px-5 pb-32 gap-3"
        style={{ paddingBottom: BottomTabInset + 40 }}
        showsVerticalScrollIndicator={false}
      >
        <Text className="section-label text-secondary">EVENT COHORTS & LEDGERS</Text>

        <View className="gap-3">
          {activeCohorts.map((cohort) => {
            const cohortM = members[cohort.id] || [];
            const cohortE = expenses[cohort.id] || [];
            const res = calculateSimplifiedDebts(cohort.id, cohortM, cohortE);
            const userBal = res.netBalances[currentUser.id] || 0;

            // Generate clean member list string
            const memberNames = cohortM
              .map((m) => m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member'))
              .filter(Boolean);

            let memberDisplay = '';
            if (memberNames.length === 0) {
              memberDisplay = '1 active member';
            } else if (memberNames.length === 1) {
              memberDisplay = memberNames[0];
            } else if (memberNames.length === 2) {
              memberDisplay = `${memberNames[0]} & ${memberNames[1]}`;
            } else if (memberNames.length === 3) {
              memberDisplay = `${memberNames[0]}, ${memberNames[1]} & ${memberNames[2]}`;
            } else {
              memberDisplay = `${memberNames[0]}, ${memberNames[1]} & ${memberNames.length - 2} others`;
            }

            return (
              <TouchableOpacity
                key={cohort.id}
                activeOpacity={0.8}
                className="card-group-item"
                onPress={() => router.push(`/event/${cohort.id}` as any)}
                onLongPress={() => {
                  setLongPressedCohort(cohort);
                  setGroupActionVisible(true);
                }}
              >
                <View className="flex-row items-center gap-3.5 flex-1">
                  <GroupAvatar
                    avatarUrl={cohort.avatarUrl || cohort.bannerUrl}
                    category={cohort.category}
                    customIcon={cohort.customIcon}
                    size={48}
                    variant="solid"
                  />
                  <View className="flex-1 justify-center">
                    {/* Line 1: Group Name + Net Balance */}
                    <View className="flex-row items-center justify-between gap-2">
                      <View className="flex-row items-center gap-2 flex-1">
                        <Text className="group-card-title font-bold text-main flex-1" numberOfLines={1}>
                          {cohort.name}
                        </Text>
                        {cohort.isArchived && (
                          <View
                            className="px-1.5 py-0.5 rounded-md"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            <Text className="text-[9px] font-bold" style={{ color: colors.cyan }}>
                              Archived (Muted)
                            </Text>
                          </View>
                        )}
                      </View>
                      <Text
                        className={`text-sm ${
                          userBal > 0.01
                            ? 'balance-positive'
                            : userBal < -0.01
                            ? 'balance-negative'
                            : 'text-secondary font-semibold'
                        }`}
                        numberOfLines={1}
                      >
                        {userBal > 0.01
                          ? `+₹${userBal.toFixed(2)}`
                          : userBal < -0.01
                          ? `-₹${Math.abs(userBal).toFixed(2)}`
                          : `₹0.00`}
                      </Text>
                    </View>

                    {/* Line 2 (Model 1: Rendered if description exists) */}
                    {cohort.description ? (
                      <Text className="group-card-desc text-secondary" numberOfLines={1}>
                        {cohort.description}
                      </Text>
                    ) : null}

                    {/* Line 3 (or Line 2 if no description): Unencapsulated Member List with icon and desaturated color */}
                    <View className="flex-row items-center gap-1.5 mt-1">
                      <Ionicons name="people-outline" size={12} color="#7E95A8" />
                      <Text
                        className="group-card-members text-slate-400 text-[11px] font-medium flex-1"
                        numberOfLines={1}
                      >
                        {memberDisplay}
                      </Text>
                    </View>
                  </View>
                </View>
              </TouchableOpacity>
            );
          })}

          {activeCohorts.length === 0 && (
            <View
              className="p-8 rounded-3xl items-center justify-center border border-dashed my-4"
              style={{
                backgroundColor: colors.surface,
                borderColor: colors.border,
              }}
            >
              <Ionicons name="people-outline" size={40} color={colors.textSecondary} />
              <Text className="text-base font-bold text-main mt-3">No Active Groups</Text>
              <Text className="text-xs text-secondary text-center mt-1">
                Create a new group or join one with an invite code.
              </Text>
            </View>
          )}
        </View>

        {/* Trash / Scheduled Deletion Section (15-Day Grace Period) */}
        {deletedCohorts.length > 0 && (
          <View className="mt-6 pt-4 border-t" style={{ borderColor: colors.border }}>
            <TouchableOpacity
              className="flex-row items-center justify-between py-2"
              onPress={() => setArchivedExpanded((prev) => !prev)}
              activeOpacity={0.7}
            >
              <View className="flex-row items-center gap-2">
                <Ionicons name="trash-outline" size={16} color={colors.textSecondary} />
                <Text className="section-label" style={{ color: colors.textSecondary }}>
                  TRASH / SCHEDULED FOR DELETION ({deletedCohorts.length})
                </Text>
              </View>
              <Ionicons
                name={archivedExpanded ? 'chevron-up' : 'chevron-down'}
                size={18}
                color={colors.textSecondary}
              />
            </TouchableOpacity>

            <Text className="text-xs mb-3 font-medium" style={{ color: colors.textSecondary }}>
              Groups stay in Trash for 15 days before permanent database deletion.
            </Text>

            {archivedExpanded && (
              <View className="gap-3">
                {deletedCohorts.map((cohort) => {
                  const deletedAtTime = cohort.deletedAt ? new Date(cohort.deletedAt).getTime() : Date.now();
                  const daysElapsed = Math.floor((Date.now() - deletedAtTime) / (1000 * 60 * 60 * 24));
                  const daysRemaining = Math.max(1, 15 - daysElapsed);

                  return (
                    <View
                      key={cohort.id}
                      className="p-4 rounded-3xl border gap-3"
                      style={{
                        backgroundColor: colors.surface,
                        borderColor: colors.border,
                        opacity: 0.9,
                      }}
                    >
                      <View className="flex-row items-center gap-3">
                        <GroupAvatar
                          avatarUrl={cohort.avatarUrl || cohort.bannerUrl}
                          category={cohort.category}
                          customIcon={cohort.customIcon}
                          size={44}
                        />
                        <View className="flex-1">
                          <Text className="text-base font-bold" style={{ color: colors.textMain }} numberOfLines={1}>
                            {cohort.name}
                          </Text>
                          <View className="flex-row items-center gap-1.5 mt-0.5">
                            <View
                              className="px-2 py-0.5 rounded-full border"
                              style={{
                                backgroundColor: 'rgba(251, 113, 133, 0.12)',
                                borderColor: 'rgba(251, 113, 133, 0.3)',
                              }}
                            >
                              <Text className="text-[10px] font-bold text-rose-400">
                                Deletes in {daysRemaining} day{daysRemaining === 1 ? '' : 's'}
                              </Text>
                            </View>
                          </View>
                        </View>
                      </View>

                      {/* Restore / Delete Permanently Actions */}
                      <View className="flex-row gap-2 pt-2 border-t" style={{ borderColor: colors.border }}>
                        <TouchableOpacity
                          className="flex-1 py-2.5 rounded-xl border flex-row items-center justify-center gap-1.5"
                          style={{
                            backgroundColor: `${colors.cyan}14`,
                            borderColor: `${colors.cyan}35`,
                          }}
                          onPress={async () => {
                            await restoreDeletedCohort(cohort.id);
                            showAlert('Group Restored', `"${cohort.name}" has been restored to active groups.`);
                          }}
                        >
                          <Ionicons name="refresh-outline" size={15} color={colors.cyan} />
                          <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                            Restore
                          </Text>
                        </TouchableOpacity>

                        <TouchableOpacity
                          className="py-2.5 px-4 rounded-xl border flex-row items-center justify-center gap-1.5"
                          style={{
                            backgroundColor: 'rgba(251, 113, 133, 0.1)',
                            borderColor: 'rgba(251, 113, 133, 0.25)',
                          }}
                          onPress={() => {
                            showAlert(
                              'Delete Permanently',
                              `Are you sure you want to permanently delete "${cohort.name}" and all its records now? This action cannot be undone.`,
                              [
                                {
                                  text: 'Delete Forever',
                                  style: 'destructive',
                                  onPress: async () => {
                                    await deleteCohortPermanently(cohort.id);
                                    showAlert('Deleted Forever', `"${cohort.name}" has been permanently removed.`);
                                  },
                                },
                                { text: 'Cancel', style: 'cancel' },
                              ]
                            );
                          }}
                        >
                          <Ionicons name="trash-outline" size={15} color="#FB7185" />
                          <Text className="text-xs font-bold text-rose-400">
                            Delete Now
                          </Text>
                        </TouchableOpacity>
                      </View>
                    </View>
                  );
                })}
              </View>
            )}
          </View>
        )}
      </ScrollView>

      {/* Speed Dial Backdrop Overlay when expanded */}
      {fabOpen && (
        <TouchableOpacity
          className="fab-backdrop"
          activeOpacity={1}
          style={{ opacity: 0.5 }}
          onPress={() => setFabOpen(false)}
        />
      )}

      {/* Expandable Speed Dial Action Buttons (Bottom-Right Pinned, Lower Position) */}
      {fabOpen && (
        <View
          style={{
            position: 'absolute',
            right: 20,
            bottom: fabBottom + 64,
            alignItems: 'flex-end',
            gap: 10,
          }}
        >
          {/* Join Group Button */}
          <TouchableOpacity
            className="fab-speed-dial-item"
            activeOpacity={0.8}
            onPress={() => {
              setFabOpen(false);
              setJoinGroupVisible(true);
            }}
          >
            <Text className="fab-speed-dial-label text-main">Join Group</Text>
            <View
              className="fab-speed-dial-icon-qr border"
              style={{ backgroundColor: `${colors.cyan}20`, borderColor: `${colors.cyan}40` }}
            >
              <Ionicons name="enter-outline" size={17} color={colors.cyan} />
            </View>
          </TouchableOpacity>

          {/* New Event / Group Button */}
          <TouchableOpacity
            className="fab-speed-dial-item"
            activeOpacity={0.8}
            onPress={() => {
              setFabOpen(false);
              setCreateGroupVisible(true);
            }}
          >
            <Text className="fab-speed-dial-label text-main">New Event Cohort</Text>
            <View className="fab-speed-dial-icon-add bg-emerald-500/15 border border-emerald-500/30">
              <Ionicons name="add" size={20} color="#34D399" />
            </View>
          </TouchableOpacity>
        </View>
      )}

      {/* Main Bottom-Right FAB Button (Lower Position directly above Tab Bar) */}
      <TouchableOpacity
        className="fab-main-btn"
        style={{
          right: 20,
          bottom: fabBottom,
        }}
        activeOpacity={0.85}
        onPress={() => setFabOpen(!fabOpen)}
      >
        <Ionicons
          name={fabOpen ? 'close' : 'add'}
          size={26}
          color={fabOpen ? '#94A3B8' : colors.cyan}
        />
      </TouchableOpacity>

      {/* Create Group Modal */}
      <CreateGroupModal
        visible={createGroupVisible}
        onClose={() => setCreateGroupVisible(false)}
      />

      {/* Join Group Modal (Code Entry or QR Scan) */}
      <JoinGroupModal
        visible={joinGroupVisible}
        onClose={() => setJoinGroupVisible(false)}
        onScanQr={() => router.push('/scan' as any)}
      />

      {/* Group Quick Action Modal */}
      {longPressedCohort && (
        <GroupActionModal
          visible={groupActionVisible}
          onClose={() => setGroupActionVisible(false)}
          cohort={longPressedCohort}
          onInvite={() => setQrCodeModalVisible(true)}
          onEdit={() => setEditGroupModalVisible(true)}
        />
      )}

      {/* QR Code Modal */}
      {longPressedCohort && (
        <QRCodeModal
          visible={qrCodeModalVisible}
          onClose={() => setQrCodeModalVisible(false)}
          cohort={longPressedCohort}
        />
      )}

      {/* Edit Group Modal */}
      {longPressedCohort && (
        <EditGroupModal
          visible={editGroupModalVisible}
          onClose={() => setEditGroupModalVisible(false)}
          cohort={longPressedCohort}
        />
      )}
    </View>
  );
}

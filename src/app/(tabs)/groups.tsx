import React, { useState } from 'react';
import { View, ScrollView, TouchableOpacity, Platform } from 'react-native';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { CreateGroupModal } from '@/components/CreateGroupModal';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

export default function GroupsScreen() {
  const router = useRouter();
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [fabOpen, setFabOpen] = useState(false);
  const { cohorts, members, expenses, currentUser } = useExpenseStore();

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
          {cohorts.map((cohort) => {
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
                      <Text className="group-card-title font-bold text-main flex-1" numberOfLines={1}>
                        {cohort.name}
                      </Text>
                      <Text
                        className={`text-sm ${userBal >= 0 ? 'balance-positive' : 'balance-negative'}`}
                        numberOfLines={1}
                      >
                        {userBal >= 0 ? `+₹${userBal.toFixed(2)}` : `-₹${Math.abs(userBal).toFixed(2)}`}
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
        </View>
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
          {/* Scan QR Button */}
          <TouchableOpacity
            className="fab-speed-dial-item"
            activeOpacity={0.8}
            onPress={() => {
              setFabOpen(false);
              router.push('/scan' as any);
            }}
          >
            <Text className="fab-speed-dial-label text-main">Scan QR Code</Text>
            <View className="fab-speed-dial-icon-qr bg-sky-500/15 border border-sky-500/30">
              <Ionicons name="qr-code-outline" size={17} color="#38BDF8" />
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
          color={fabOpen ? '#94A3B8' : '#38BDF8'}
        />
      </TouchableOpacity>

      {/* Create Group Modal */}
      <CreateGroupModal
        visible={createGroupVisible}
        onClose={() => setCreateGroupVisible(false)}
      />
    </View>
  );
}

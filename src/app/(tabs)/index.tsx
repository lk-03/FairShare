import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  useColorScheme,
  ActivityIndicator,
  Image,
  Modal,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getThemeGradientColors, getThemePalette, getActiveThemeClass } from '@/store/useThemeStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { AddExpenseModal } from '@/components/AddExpenseModal';
import { ItemizedReceiptModal } from '@/components/ItemizedReceiptModal';
import { SelectGroupModal } from '@/components/SelectGroupModal';
import { AppLogo } from '@/components/ui/AppLogo';
import { CreateGroupModal } from '@/components/CreateGroupModal';
import { ThemeSettingsModal } from '@/components/ThemeSettingsModal';
import { ThemeGradientHeader } from '@/components/ui/ThemeGradientHeader';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { EmptyState } from '@/components/ui/EmptyState';
import { EventCohort, Expense } from '@/types';
import { Text } from '@/components/ui/Text';
import { JoinGroupModal } from '@/components/JoinGroupModal';
import { StaleNeedsReminderModal } from '@/components/StaleNeedsReminderModal';
import { SplitwiseImportModal } from '@/components/SplitwiseImportModal';
import { GroupActionModal } from '@/components/GroupActionModal';
import { QRCodeModal } from '@/components/QRCodeModal';
import { EditGroupModal } from '@/components/EditGroupModal';

export default function HomeScreen() {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const [selectGroupVisible, setSelectGroupVisible] = useState(false);
  const [selectedCohortId, setSelectedCohortId] = useState<string | undefined>(undefined);
  const [addExpenseVisible, setAddExpenseVisible] = useState(false);
  const [itemizedReceiptVisible, setItemizedReceiptVisible] = useState(false);
  const [pendingAction, setPendingAction] = useState<'add_expense' | 'scan_receipt'>('add_expense');
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [joinGroupVisible, setJoinGroupVisible] = useState(false);
  const [themeSettingsVisible, setThemeSettingsVisible] = useState(false);
  const [splitwiseImportVisible, setSplitwiseImportVisible] = useState(false);
  const [longPressedCohort, setLongPressedCohort] = useState<EventCohort | null>(null);
  const [groupActionVisible, setGroupActionVisible] = useState(false);
  const [qrCodeModalVisible, setQrCodeModalVisible] = useState(false);
  const [editGroupModalVisible, setEditGroupModalVisible] = useState(false);

  const {
    cohorts,
    members,
    expenses,
    currentUser,
    hasCompletedOnboarding,
    isLoading,
    isSyncing,
    error,
    clearError,
    fetchInitialData,
    refreshAll,
  } = useExpenseStore();

  const gradientColors = getThemeGradientColors(themeBase, colorScheme, systemScheme);

  // Bootstrap fetch on mount & ensure authenticated onboarding
  useEffect(() => {
    if (!hasCompletedOnboarding) {
      router.replace('/welcome' as any);
      return;
    }
    fetchInitialData();
  }, [hasCompletedOnboarding]);

  // Active cohorts visible on the home dashboard (excludes soft-deleted / trash cohorts)
  const activeCohorts = useMemo(
    () => cohorts.filter((c) => !c.isDeleted),
    [cohorts]
  );

  // Compute Net Balance across active, non-archived cohorts (archived cohorts are muted from totals)
  const { totalOwed, totalOwe, netTotal } = useMemo(() => {
    let owed = 0;
    let owe = 0;

    activeCohorts
      .filter((cohort) => !cohort.isArchived)
      .forEach((cohort) => {
        const res = calculateSimplifiedDebts(
          cohort.id,
          members[cohort.id] || [],
          expenses[cohort.id] || []
        );
        const userBal = res.netBalances[currentUser.id] || 0;
        if (userBal > 0) owed += userBal;
        else if (userBal < 0) owe += Math.abs(userBal);
      });

    return {
      totalOwed: owed,
      totalOwe: owe,
      netTotal: owed - owe,
    };
  }, [activeCohorts, members, expenses, currentUser.id]);

  // Flattened recent expenses across all active cohorts
  const recentExpenses = useMemo(() => {
    const activeCohortIds = new Set(activeCohorts.map((c) => c.id));
    const allExps: Expense[] = Object.entries(expenses)
      .filter(([cohortId]) => activeCohortIds.has(cohortId))
      .flatMap(([_, exps]) => exps);
    return allExps
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 4);
  }, [activeCohorts, expenses]);

  const handleOpenAddExpense = () => {
    if (activeCohorts.length === 0) {
      setCreateGroupVisible(true);
    } else if (activeCohorts.length === 1) {
      setSelectedCohortId(activeCohorts[0].id);
      setAddExpenseVisible(true);
    } else {
      setPendingAction('add_expense');
      setSelectGroupVisible(true);
    }
  };

  const handleOpenScanReceipt = () => {
    if (activeCohorts.length === 0) {
      setCreateGroupVisible(true);
    } else if (activeCohorts.length === 1) {
      setSelectedCohortId(activeCohorts[0].id);
      setItemizedReceiptVisible(true);
    } else {
      setPendingAction('scan_receipt');
      setSelectGroupVisible(true);
    }
  };

  const handleGroupSelected = (cohort: EventCohort) => {
    setSelectGroupVisible(false);
    setSelectedCohortId(cohort.id);
    if (pendingAction === 'scan_receipt') {
      setItemizedReceiptVisible(true);
    } else {
      setAddExpenseVisible(true);
    }
  };

  return (
    <View className="flex-1 bg-screen">
      <ScrollView
        className="flex-1"
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: BottomTabInset + 32 }}
        refreshControl={
          <RefreshControl
            refreshing={isSyncing}
            onRefresh={refreshAll}
            tintColor={colors.cyan}
            colors={[colors.cyan]}
          />
        }
      >
        {/* HERO GRADIENT HEADER (Revolut Aesthetic) */}
        <ThemeGradientHeader
          colors={gradientColors}
          className="px-5 pb-8 rounded-b-[40px] shadow-sm"
        >
          {/* Top Bar Header */}
          <View className="flex-row items-center justify-between py-3 mb-4">
            <View className="flex-row items-center gap-2.5">
              <AppLogo size={32} withShadow withGlow />
              <Text className="text-2xl font-black text-main tracking-tight">
                FairShare
              </Text>
            </View>

            {/* User Profile Avatar */}
            <TouchableOpacity
              activeOpacity={0.8}
              className="w-10 h-10 rounded-full items-center justify-center overflow-hidden"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderWidth: 1,
                borderColor: colors.border,
                elevation: 0,
                shadowOpacity: 0,
              }}
              onPress={() => router.push('/profile' as any)}
            >
              {currentUser.avatarUrl ? (
                <Image
                  source={{ uri: currentUser.avatarUrl }}
                  className="w-10 h-10 rounded-full"
                />
              ) : (
                <Text className="text-main font-bold text-sm">
                  {currentUser.fullName ? currentUser.fullName.charAt(0).toUpperCase() : 'U'}
                </Text>
              )}
            </TouchableOpacity>
          </View>

          {/* Centered Hero Net Balance */}
          <View className="items-center justify-center my-4">
            <View className="bg-accent-pill px-3.5 py-1 rounded-full border border-surface mb-2">
              <Text className="text-[11px] font-semibold text-secondary tracking-wide uppercase">
                Personal • Net Balance
              </Text>
            </View>

            <Text className="text-5xl font-bold text-main tracking-tight my-1">
              {netTotal > 0.01
                ? `+₹${netTotal.toFixed(2)}`
                : netTotal < -0.01
                ? `-₹${Math.abs(netTotal).toFixed(2)}`
                : `₹0.00`}
            </Text>

            <View className="flex-row items-center gap-1.5 mt-1">
              <View
                className={`w-2 h-2 rounded-full ${
                  netTotal > 0.01
                    ? 'bg-emerald-400'
                    : netTotal < -0.01
                    ? 'bg-rose-400'
                    : 'bg-slate-400'
                }`}
              />
              <Text className="text-xs font-normal text-secondary">
                {netTotal > 0.01
                  ? 'Total amount you are owed'
                  : netTotal < -0.01
                  ? 'Total amount you owe'
                  : 'You are all settled up'}
              </Text>
            </View>
          </View>

          {/* Frosted Action Buttons Row */}
          <View className="flex-row justify-around items-center mt-6 pt-2">
            {/* Add Expense */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={handleOpenAddExpense}
            >
              <View
                className="w-14 h-14 rounded-full items-center justify-center"
                style={{
                  backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                  borderWidth: 1,
                  borderColor: colors.border,
                  elevation: 0,
                  shadowOpacity: 0,
                }}
              >
                <Ionicons name="add" size={26} color={colors.cyan} />
              </View>
              <Text className="text-xs font-semibold text-main">Add</Text>
            </TouchableOpacity>

            {/* Scan Receipt */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={handleOpenScanReceipt}
            >
              <View
                className="w-14 h-14 rounded-full items-center justify-center"
                style={{
                  backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                  borderWidth: 1,
                  borderColor: colors.border,
                  elevation: 0,
                  shadowOpacity: 0,
                }}
              >
                <Ionicons name="receipt-outline" size={22} color={colors.cyan} />
              </View>
              <Text className="text-xs font-semibold text-main">Scan Receipt</Text>
            </TouchableOpacity>

            {/* Join Group */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={() => setJoinGroupVisible(true)}
            >
              <View
                className="w-14 h-14 rounded-full items-center justify-center"
                style={{
                  backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                  borderWidth: 1,
                  borderColor: colors.border,
                  elevation: 0,
                  shadowOpacity: 0,
                }}
              >
                <Ionicons name="enter-outline" size={24} color={colors.cyan} />
              </View>
              <Text className="text-xs font-semibold text-main">Join Group</Text>
            </TouchableOpacity>

            {/* New Group */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={() => setCreateGroupVisible(true)}
            >
              <View
                className="w-14 h-14 rounded-full items-center justify-center"
                style={{
                  backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                  borderWidth: 1,
                  borderColor: colors.border,
                  elevation: 0,
                  shadowOpacity: 0,
                }}
              >
                <Ionicons name="people-outline" size={22} color={colors.cyan} />
              </View>
              <Text className="text-xs font-semibold text-main">New Group</Text>
            </TouchableOpacity>
          </View>
        </ThemeGradientHeader>

        {/* Offline / Sync Notification Banner */}
        {error && (
          <View className="mx-5 mt-4 p-3.5 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex-row items-center justify-between">
            <View className="flex-row items-center gap-2.5 flex-1 pr-2">
              <Ionicons name="cloud-offline-outline" size={18} color="#F59E0B" />
              <Text className="text-xs font-medium text-amber-500 flex-1">{error}</Text>
            </View>
            <TouchableOpacity onPress={clearError}>
              <Ionicons name="close" size={16} color="#F59E0B" />
            </TouchableOpacity>
          </View>
        )}

        {/* LOWER SURFACE CONTENT */}
        <View className="px-5 pt-6 gap-6">
          {/* GROUPS SECTION */}
          <View>
            <View className="flex-row justify-between items-center mb-3">
              <Text className="text-xl font-bold text-main">Groups</Text>
              <View className="flex-row items-center gap-3">
                <TouchableOpacity
                  onPress={() => setSplitwiseImportVisible(true)}
                  className="flex-row items-center gap-1 px-2.5 py-1 rounded-xl bg-emerald-500/10 border border-emerald-500/30"
                  activeOpacity={0.7}
                >
                  <Ionicons name="swap-horizontal" size={13} color="#10B981" />
                  <Text className="text-[11px] font-bold text-emerald-500">Import Splitwise</Text>
                </TouchableOpacity>

                {cohorts.length > 0 && (
                  <TouchableOpacity onPress={() => router.push('/groups' as any)}>
                    <Text className="text-xs font-semibold" style={{ color: colors.cyan }}>View All ({cohorts.length})</Text>
                  </TouchableOpacity>
                )}
              </View>
            </View>

            {isLoading && cohorts.length === 0 ? (
              <View className="card-main p-8 items-center justify-center">
                <ActivityIndicator size="small" color={colors.cyan} />
                <Text className="text-xs text-secondary mt-3 font-medium">Loading your groups...</Text>
              </View>
            ) : activeCohorts.length === 0 ? (
              <EmptyState
                icon="people-outline"
                title="No Groups Yet"
                description="Create or join an event cohort to start splitting expenses with friends, roommates, or travel partners."
                primaryActionLabel="Create First Group"
                onPrimaryAction={() => setCreateGroupVisible(true)}
                secondaryActionLabel="Scan Invite QR"
                onSecondaryAction={() => router.push('/scan' as any)}
              />
            ) : (
              <ScrollView
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerClassName="gap-3.5 pr-5 py-1"
              >
                {activeCohorts.map((cohort) => {
                  const res = calculateSimplifiedDebts(
                    cohort.id,
                    members[cohort.id] || [],
                    expenses[cohort.id] || []
                  );
                  const userBal = res.netBalances[currentUser.id] || 0;

                  return (
                    <TouchableOpacity
                      key={cohort.id}
                      activeOpacity={0.75}
                      className="card-main p-4 w-44 justify-between gap-3"
                      onPress={() => router.push(`/event/${cohort.id}` as any)}
                      onLongPress={() => {
                        setLongPressedCohort(cohort);
                        setGroupActionVisible(true);
                      }}
                    >
                      <View className="flex-row items-center justify-between">
                        <GroupAvatar
                          avatarUrl={cohort.avatarUrl || cohort.bannerUrl}
                          category={cohort.category}
                          customIcon={cohort.customIcon}
                          size={40}
                        />
                        <View
                          className="px-2 py-0.5 rounded-full"
                          style={{
                            backgroundColor:
                              userBal > 0
                                ? 'rgba(52, 211, 153, 0.15)'
                                : userBal < 0
                                ? 'rgba(251, 113, 133, 0.15)'
                                : isDark
                                ? colors.accentPill
                                : '#F1F5F9',
                          }}
                        >
                          <Text
                            className={`text-[10px] font-bold ${
                              userBal > 0
                                ? 'text-positive'
                                : userBal < 0
                                ? 'text-negative'
                                : 'text-secondary'
                            }`}
                          >
                            {userBal > 0 ? '+₹' : userBal < 0 ? '-₹' : '₹'}
                            {Math.abs(userBal).toFixed(0)}
                          </Text>
                        </View>
                      </View>

                      <View>
                        <Text className="text-sm font-bold text-main" numberOfLines={1}>
                          {cohort.name}
                        </Text>
                        <Text className="text-xs text-secondary mt-0.5" numberOfLines={1}>
                          {(members[cohort.id] || []).length} members
                        </Text>
                        {cohort.isArchived && (
                          <View
                            className="px-1.5 py-0.5 rounded-md mt-1 self-start"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            <Text className="text-[9px] font-bold" style={{ color: colors.cyan }}>
                              Archived (Muted)
                            </Text>
                          </View>
                        )}
                      </View>
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            )}
          </View>

          {/* RECENT ACTIVITY SECTION */}
          <View>
            <View className="flex-row justify-between items-center mb-3">
              <Text className="section-label">RECENT ACTIVITY</Text>
              {recentExpenses.length > 0 && (
                <TouchableOpacity onPress={() => router.push('/activity' as any)}>
                  <Text className="text-xs font-semibold" style={{ color: colors.cyan }}>See All</Text>
                </TouchableOpacity>
              )}
            </View>

            {isLoading && recentExpenses.length === 0 ? (
              <View className="card-main p-6 items-center justify-center">
                <ActivityIndicator size="small" color={colors.cyan} />
                <Text className="text-xs text-secondary mt-2 font-medium">Fetching activity...</Text>
              </View>
            ) : recentExpenses.length === 0 ? (
              <EmptyState
                icon="receipt-outline"
                title="No Recent Activity"
                description="When you or your group members add an expense or split a bill, it will appear here."
                primaryActionLabel="Add an Expense"
                onPrimaryAction={handleOpenAddExpense}
                variant="card"
              />
            ) : (
              <View className="gap-3">
                {recentExpenses.map((item) => (
                  <TouchableOpacity
                    key={item.id}
                    activeOpacity={0.8}
                    className="card-item"
                    onPress={() => router.push(`/event/${item.cohortId}` as any)}
                  >
                    <View className="flex-row items-center flex-1 pr-4">
                      <View className="mr-4">
                        <CategoryIcon
                          category={item.category}
                          customIcon={item.customIcon}
                          size={44}
                          variant="solid"
                        />
                      </View>
                      <View className="flex-1">
                        <Text className="font-bold text-main text-sm mb-0.5" numberOfLines={1}>
                          {item.title}
                        </Text>
                        <Text className="text-xs font-normal text-secondary">
                          Paid by {item.paidByUserId === currentUser.id ? 'You' : 'Member'} • ₹
                          {item.totalAmount}
                        </Text>
                      </View>
                    </View>
                    <Text className="font-semibold text-main text-base">₹{item.totalAmount}</Text>
                  </TouchableOpacity>
                ))}
              </View>
            )}
          </View>
        </View>
      </ScrollView>

      {/* Theme Settings Modal */}
      <ThemeSettingsModal
        visible={themeSettingsVisible}
        onClose={() => setThemeSettingsVisible(false)}
      />

      {/* Select Group Modal */}
      <SelectGroupModal
        visible={selectGroupVisible}
        onClose={() => setSelectGroupVisible(false)}
        onSelectGroup={handleGroupSelected}
        onCreateNewGroup={() => setCreateGroupVisible(true)}
      />

      {/* Add Expense Modal */}
      <AddExpenseModal
        visible={addExpenseVisible}
        onClose={() => {
          setAddExpenseVisible(false);
          setSelectedCohortId(undefined);
        }}
        cohortId={selectedCohortId}
      />

      {/* Itemized Receipt Scanner (OCR) Modal */}
      {itemizedReceiptVisible && (
        <ItemizedReceiptModal
          visible={itemizedReceiptVisible}
          onClose={() => {
            setItemizedReceiptVisible(false);
            setSelectedCohortId(undefined);
          }}
          cohortId={selectedCohortId || cohorts[0]?.id || ''}
        />
      )}

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

      {/* Splitwise CSV Importer Modal */}
      <SplitwiseImportModal
        visible={splitwiseImportVisible}
        onClose={() => setSplitwiseImportVisible(false)}
        onSuccess={(cohortId) => {
          router.push(`/event/${cohortId}` as any);
        }}
      />

      {/* Stale Unbought Items Popup Reminder on App Open */}
      <StaleNeedsReminderModal />

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

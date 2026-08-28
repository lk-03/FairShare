import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  useColorScheme,
  ActivityIndicator,
} from 'react-native';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getThemeGradientColors } from '@/store/useThemeStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { AddExpenseModal } from '@/components/AddExpenseModal';
import { SelectGroupModal } from '@/components/SelectGroupModal';
import { CreateGroupModal } from '@/components/CreateGroupModal';
import { ThemeSettingsModal } from '@/components/ThemeSettingsModal';
import { ThemeGradientHeader } from '@/components/ui/ThemeGradientHeader';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { EmptyState } from '@/components/ui/EmptyState';
import { EventCohort, Expense } from '@/types';
import { Text } from '@/components/ui/Text';
import { StaleNeedsReminderModal } from '@/components/StaleNeedsReminderModal';

export default function HomeScreen() {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();

  const [selectGroupVisible, setSelectGroupVisible] = useState(false);
  const [selectedCohortId, setSelectedCohortId] = useState<string | undefined>(undefined);
  const [addExpenseVisible, setAddExpenseVisible] = useState(false);
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [themeSettingsVisible, setThemeSettingsVisible] = useState(false);

  const {
    cohorts,
    members,
    expenses,
    currentUser,
    isLoading,
    isSyncing,
    error,
    clearError,
    fetchInitialData,
    refreshAll,
  } = useExpenseStore();

  const gradientColors = getThemeGradientColors(themeBase, colorScheme, systemScheme);

  // Bootstrap fetch on mount
  useEffect(() => {
    fetchInitialData();
  }, []);

  // Compute Net Balance across all cohorts
  const { totalOwed, totalOwe, netTotal } = useMemo(() => {
    let owed = 0;
    let owe = 0;

    cohorts.forEach((cohort) => {
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
  }, [cohorts, members, expenses, currentUser.id]);

  // Flattened recent expenses across all cohorts
  const recentExpenses = useMemo(() => {
    const allExps: Expense[] = Object.values(expenses).flat();
    return allExps
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 4);
  }, [expenses]);

  const handleOpenAddExpense = () => {
    if (cohorts.length === 0) {
      setCreateGroupVisible(true);
    } else if (cohorts.length === 1) {
      setSelectedCohortId(cohorts[0].id);
      setAddExpenseVisible(true);
    } else {
      setSelectGroupVisible(true);
    }
  };

  const handleGroupSelected = (cohort: EventCohort) => {
    setSelectGroupVisible(false);
    setSelectedCohortId(cohort.id);
    setAddExpenseVisible(true);
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
            tintColor="#38BDF8"
            colors={['#38BDF8', '#2563EB']}
          />
        }
      >
        {/* HERO GRADIENT HEADER (Revolut Aesthetic) */}
        <ThemeGradientHeader
          colors={gradientColors}
          className="px-5 pb-8 rounded-b-[40px] shadow-sm"
        >
          {/* Top Bar Controls */}
          <View className="flex-row items-center justify-between py-3 mb-4">
            {/* User Profile Avatar */}
            <TouchableOpacity
              activeOpacity={0.8}
              className="w-10 h-10 rounded-full bg-accent-pill border border-surface items-center justify-center"
              onPress={() => router.push('/profile' as any)}
            >
              <Text className="text-main font-bold text-sm">
                {currentUser.fullName ? currentUser.fullName.charAt(0).toUpperCase() : 'U'}
              </Text>
            </TouchableOpacity>

            {/* Quick Search Bar Pill */}
            <TouchableOpacity
              activeOpacity={0.8}
              className="flex-1 mx-3 px-4 py-2 rounded-full bg-accent-pill border border-surface flex-row items-center gap-2"
              onPress={() => router.push('/activity' as any)}
            >
              <Ionicons name="search" size={16} color="#94A3B8" />
              <Text className="text-xs text-secondary font-normal">Search expenses, groups...</Text>
            </TouchableOpacity>

            {/* Profile & Settings Icon */}
            <TouchableOpacity
              activeOpacity={0.8}
              className="w-10 h-10 rounded-full bg-accent-pill border border-surface items-center justify-center"
              onPress={() => router.push('/profile' as any)}
            >
              <Ionicons name="settings-outline" size={19} color="#94A3B8" />
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
              {netTotal >= 0 ? `+₹${netTotal.toFixed(2)}` : `-₹${Math.abs(netTotal).toFixed(2)}`}
            </Text>

            <View className="flex-row items-center gap-1.5 mt-1">
              <View
                className={`w-2 h-2 rounded-full ${
                  netTotal >= 0 ? 'bg-emerald-400' : 'bg-rose-400'
                }`}
              />
              <Text className="text-xs font-normal text-secondary">
                {netTotal >= 0 ? 'Total amount you are owed' : 'Total amount you owe'}
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
              <View className="w-14 h-14 rounded-full bg-accent-pill border border-surface items-center justify-center shadow-sm">
                <Ionicons name="add" size={26} color="#E2E8F0" />
              </View>
              <Text className="text-xs font-medium text-main">Add</Text>
            </TouchableOpacity>

            {/* Scan Receipt */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={handleOpenAddExpense}
            >
              <View className="w-14 h-14 rounded-full bg-accent-pill border border-surface items-center justify-center shadow-sm">
                <Ionicons name="receipt-outline" size={22} color="#E2E8F0" />
              </View>
              <Text className="text-xs font-medium text-main">Scan Receipt</Text>
            </TouchableOpacity>

            {/* Scan QR */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={() => router.push('/scan' as any)}
            >
              <View className="w-14 h-14 rounded-full bg-accent-pill border border-surface items-center justify-center shadow-sm">
                <Ionicons name="qr-code-outline" size={22} color="#E2E8F0" />
              </View>
              <Text className="text-xs font-medium text-main">Scan QR</Text>
            </TouchableOpacity>

            {/* New Group */}
            <TouchableOpacity
              activeOpacity={0.75}
              className="items-center gap-2"
              onPress={() => setCreateGroupVisible(true)}
            >
              <View className="w-14 h-14 rounded-full bg-accent-pill border border-surface items-center justify-center shadow-sm">
                <Ionicons name="people-outline" size={22} color="#E2E8F0" />
              </View>
              <Text className="text-xs font-medium text-main">New Group</Text>
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
              {cohorts.length > 0 && (
                <TouchableOpacity onPress={() => router.push('/groups' as any)}>
                  <Text className="text-xs font-semibold text-sky-400">View All ({cohorts.length})</Text>
                </TouchableOpacity>
              )}
            </View>

            {isLoading && cohorts.length === 0 ? (
              <View className="card-main p-8 items-center justify-center">
                <ActivityIndicator size="small" color="#38BDF8" />
                <Text className="text-xs text-secondary mt-3 font-medium">Loading your groups...</Text>
              </View>
            ) : cohorts.length === 0 ? (
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
                className="mt-1"
                contentContainerStyle={{ paddingRight: 20 }}
              >
                {cohorts.map((cohort) => {
                  const cohortM = members[cohort.id] || [];
                  const cohortE = expenses[cohort.id] || [];
                  const res = calculateSimplifiedDebts(cohort.id, cohortM, cohortE);
                  const userBal = res.netBalances[currentUser.id] || 0;

                  return (
                    <TouchableOpacity
                      key={cohort.id}
                      activeOpacity={0.8}
                      style={{ width: 175 }}
                      className="rounded-3xl p-5 border border-surface bg-surface shadow-sm mr-4 flex-col items-start"
                      onPress={() => router.push(`/event/${cohort.id}` as any)}
                    >
                      <View className="mb-4">
                        <GroupAvatar
                          avatarUrl={cohort.avatarUrl || cohort.bannerUrl}
                          category={cohort.category}
                          customIcon={cohort.customIcon}
                          size={48}
                          variant="solid"
                        />
                      </View>
                      <Text className="font-bold text-main mb-1 text-base w-full" numberOfLines={1}>
                        {cohort.name}
                      </Text>
                      <Text className="text-xs font-normal text-secondary mb-3">
                        {cohortM.length} {cohortM.length === 1 ? 'member' : 'members'}
                      </Text>
                      <Text
                        className={`font-semibold text-base ${
                          userBal >= 0 ? 'text-positive' : 'text-negative'
                        }`}
                      >
                        {userBal >= 0
                          ? `+₹${userBal.toFixed(2)}`
                          : `-₹${Math.abs(userBal).toFixed(2)}`}
                      </Text>
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
                  <Text className="text-xs font-semibold text-sky-400">See All</Text>
                </TouchableOpacity>
              )}
            </View>

            {isLoading && recentExpenses.length === 0 ? (
              <View className="card-main p-6 items-center justify-center">
                <ActivityIndicator size="small" color="#38BDF8" />
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

      {/* Create Group Modal */}
      <CreateGroupModal
        visible={createGroupVisible}
        onClose={() => setCreateGroupVisible(false)}
      />

      {/* Stale Unbought Items Popup Reminder on App Open */}
      <StaleNeedsReminderModal />
    </View>
  );
}

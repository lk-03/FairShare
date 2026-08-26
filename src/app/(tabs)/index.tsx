import React, { useState } from 'react';
import { View, ScrollView, TouchableOpacity, useColorScheme } from 'react-native';
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
import { EventCohort } from '@/types';

// Custom UI Components
import { Text } from '@/components/ui/Text';

export default function HomeScreen() {
  const router = useRouter();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();

  const [selectGroupVisible, setSelectGroupVisible] = useState(false);
  const [selectedCohortId, setSelectedCohortId] = useState<string | undefined>(undefined);
  const [addExpenseVisible, setAddExpenseVisible] = useState(false);
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const [themeSettingsVisible, setThemeSettingsVisible] = useState(false);

  const { cohorts, members, expenses, currentUser } = useExpenseStore();

  const gradientColors = getThemeGradientColors(themeBase, colorScheme, systemScheme);

  let totalOwed = 0;
  let totalOwe = 0;

  cohorts.forEach((cohort) => {
    const res = calculateSimplifiedDebts(
      cohort.id,
      members[cohort.id] || [],
      expenses[cohort.id] || []
    );
    const userBal = res.netBalances[currentUser.id] || 0;
    if (userBal > 0) totalOwed += userBal;
    else if (userBal < 0) totalOwe += Math.abs(userBal);
  });

  const netTotal = totalOwed - totalOwe;

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
                {currentUser.fullName.charAt(0)}
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
              <View className={`w-2 h-2 rounded-full ${netTotal >= 0 ? 'bg-emerald-400' : 'bg-rose-400'}`} />
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

        {/* LOWER SURFACE CONTENT */}
        <View className="px-5 pt-6 gap-6">
          {/* GROUPS SECTION */}
          <View>
            <View className="mb-3">
              <Text className="text-xl font-bold text-main">Groups</Text>
            </View>

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
                      <CategoryIcon
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
                      {userBal >= 0 ? `+₹${userBal.toFixed(2)}` : `-₹${Math.abs(userBal).toFixed(2)}`}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          </View>

          {/* RECENT ACTIVITY SECTION */}
          <View>
            <Text className="section-label mb-3">RECENT ACTIVITY</Text>

            <View className="gap-3">
              {Object.values(expenses)
                .flat()
                .slice(0, 4)
                .map((item) => (
                  <View key={item.id} className="card-item">
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
                        <Text className="font-bold text-main text-sm mb-0.5">{item.title}</Text>
                        <Text className="text-xs font-normal text-secondary">
                          Paid by {item.paidByUserId === currentUser.id ? 'You' : 'Member'} • ₹{item.totalAmount}
                        </Text>
                      </View>
                    </View>
                    <Text className="font-semibold text-main text-base">₹{item.totalAmount}</Text>
                  </View>
                ))}
            </View>
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
    </View>
  );
}


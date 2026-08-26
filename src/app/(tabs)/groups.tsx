import React, { useState } from 'react';
import { View, ScrollView, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { CreateGroupModal } from '@/components/CreateGroupModal';
import { Ionicons } from '@expo/vector-icons';
import { Button } from '@/components/ui/Button';
import { Text } from '@/components/ui/Text';

export default function GroupsScreen() {
  const router = useRouter();
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const { cohorts, members, expenses, currentUser } = useExpenseStore();

  return (
    <View className="flex-1 bg-screen pt-safe">
      <View className="screen-header">
        <Text className="screen-title">Groups</Text>
        <Button variant="ghost" size="icon" className="btn-icon-circle" onPress={() => setCreateGroupVisible(true)}>
          <Ionicons name="add" size={20} color="#94A3B8" />
        </Button>
      </View>

      <ScrollView
        contentContainerClassName="px-5 pb-10 gap-4"
        style={{ paddingBottom: BottomTabInset + 24 }}
        showsVerticalScrollIndicator={false}
      >
        <View className="flex-row items-center justify-between mb-2">
          <Text className="text-sm font-bold text-main">Event Cohorts & Ledgers</Text>
          <View className="flex-row gap-4 items-center">
            <TouchableOpacity onPress={() => setCreateGroupVisible(true)}>
              <Text className="text-sm font-semibold text-sky-500">+ New Event</Text>
            </TouchableOpacity>
            <TouchableOpacity onPress={() => router.push('/scan' as any)}>
              <Text className="text-sm font-semibold text-sky-500">Scan QR</Text>
            </TouchableOpacity>
          </View>
        </View>

        <View className="gap-3">
          {cohorts.map((cohort) => {
            const cohortM = members[cohort.id] || [];
            const cohortE = expenses[cohort.id] || [];
            const res = calculateSimplifiedDebts(cohort.id, cohortM, cohortE);
            const userBal = res.netBalances[currentUser.id] || 0;

            return (
              <TouchableOpacity
                key={cohort.id}
                activeOpacity={0.8}
                className="card-item"
                onPress={() => router.push(`/event/${cohort.id}` as any)}
              >
                <View className="flex-row items-center gap-4 flex-1 pr-4">
                  <CategoryIcon category={cohort.category} customIcon={cohort.customIcon} size={48} variant="solid" />
                  <View className="flex-1">
                    <Text className="text-lg font-bold text-main">{cohort.name}</Text>
                    <Text className="text-sm text-secondary" numberOfLines={2}>
                      {cohort.description || `${cohortM.length} active members`}
                    </Text>
                  </View>
                </View>
                <Text className={`text-base ${userBal >= 0 ? 'balance-positive' : 'balance-negative'}`}>
                  {userBal >= 0 ? `+₹${userBal.toFixed(2)}` : `-₹${Math.abs(userBal).toFixed(2)}`}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </ScrollView>

      <CreateGroupModal
        visible={createGroupVisible}
        onClose={() => setCreateGroupVisible(false)}
      />
    </View>
  );
}

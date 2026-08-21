import React, { useState } from 'react';
import { StyleSheet, View, ScrollView, TouchableOpacity, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { CreateGroupModal } from '@/components/CreateGroupModal';

export default function GroupsScreen() {
  const router = useRouter();
  const theme = useTheme();
  const [createGroupVisible, setCreateGroupVisible] = useState(false);
  const { cohorts, members, expenses, currentUser } = useExpenseStore();

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <ThemedText type="title">Groups</ThemedText>
      </View>

      <ScrollView
        contentContainerStyle={[styles.scrollContent, { paddingBottom: BottomTabInset + 24 }]}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.groupsOnlyContainer}>
          <View style={styles.sectionHeader}>
            <ThemedText type="subtitle" style={styles.sectionTitle}>
              Event Cohorts & Ledgers
            </ThemedText>
            <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center' }}>
              <TouchableOpacity onPress={() => setCreateGroupVisible(true)}>
                <ThemedText type="linkPrimary">+ New Event</ThemedText>
              </TouchableOpacity>
              <TouchableOpacity onPress={() => router.push('/scan' as any)}>
                <ThemedText type="linkPrimary">Scan QR</ThemedText>
              </TouchableOpacity>
            </View>
          </View>

          <View style={styles.groupsGrid}>
            {cohorts.map((cohort) => {
              const cohortM = members[cohort.id] || [];
              const cohortE = expenses[cohort.id] || [];
              const res = calculateSimplifiedDebts(cohort.id, cohortM, cohortE);
              const userBal = res.netBalances[currentUser.id] || 0;

              return (
                <TouchableOpacity
                  key={cohort.id}
                  style={[
                    styles.groupFullCard,
                    { backgroundColor: theme.backgroundElement },
                  ]}
                  activeOpacity={0.8}
                  onPress={() => router.push(`/event/${cohort.id}` as any)}
                >
                  <CategoryIcon
                    category={cohort.category}
                    customIcon={cohort.customIcon}
                    size={42}
                  />
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.groupNameLarge, { color: theme.text }]}>
                      {cohort.name}
                    </Text>
                    <Text style={[styles.groupDesc, { color: theme.textSecondary }]}>
                      {cohort.description || `${cohortM.length} active members`}
                    </Text>
                  </View>
                  <Text
                    style={[
                      styles.groupBalanceLarge,
                      { color: userBal >= 0 ? '#10B981' : '#EF4444' },
                    ]}
                  >
                    {userBal >= 0 ? `+₹${userBal.toFixed(2)}` : `-₹${Math.abs(userBal).toFixed(2)}`}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>
        </View>
      </ScrollView>

      <CreateGroupModal
        visible={createGroupVisible}
        onClose={() => setCreateGroupVisible(false)}
      />
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 16,
    paddingTop: 60,
    paddingBottom: 16,
  },
  scrollContent: {
    padding: 16,
    gap: 20,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '700',
  },
  groupsOnlyContainer: {
    gap: 16,
  },
  groupsGrid: {
    gap: 12,
  },
  groupFullCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 16,
    gap: 14,
  },
  groupNameLarge: {
    fontSize: 17,
    fontWeight: '700',
  },
  groupDesc: {
    fontSize: 13,
    marginTop: 2,
  },
  groupBalanceLarge: {
    fontSize: 16,
    fontWeight: '800',
  },
});

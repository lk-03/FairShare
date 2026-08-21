import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  ScrollView,
  TouchableOpacity,
  Text,
  Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import { TitleBar } from '@/components/title-bar';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { BottomTabInset } from '@/constants/theme';
import { AddExpenseModal } from '@/components/AddExpenseModal';
import { CreateGroupModal } from '@/components/CreateGroupModal';
import { CategoryIcon } from '@/components/ui/CategoryIcon';

export default function HomeScreen() {
  const router = useRouter();
  const theme = useTheme();
  const [addExpenseVisible, setAddExpenseVisible] = useState(false);
  const [createGroupVisible, setCreateGroupVisible] = useState(false);

  const { cohorts, members, expenses, currentUser } = useExpenseStore();

  // Aggregate net balance across all event cohorts
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

  return (
    <ThemedView style={styles.container}>
      {/* Top Title Bar */}
      <TitleBar
        title="fairsharew"
        isGroupsOnlyView={false}
        onNotificationPress={() => alert('Notifications')}
        onProfilePress={() => alert(`Logged in as ${currentUser.fullName}`)}
      />

      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: BottomTabInset + 24 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Total Net Balance Card */}
            <View
              style={[
                styles.balanceCard,
                { backgroundColor: theme.backgroundElement },
              ]}
            >
              <View style={styles.balanceHeader}>
                <Text style={[styles.balanceSubTitle, { color: theme.textSecondary }]}>
                  Overall Net Balance
                </Text>
                <View
                  style={[
                    styles.badge,
                    {
                      backgroundColor:
                        netTotal >= 0
                          ? 'rgba(16, 185, 129, 0.15)'
                          : 'rgba(239, 68, 68, 0.15)',
                    },
                  ]}
                >
                  <Text
                    style={[
                      styles.badgeText,
                      { color: netTotal >= 0 ? '#10B981' : '#EF4444' },
                    ]}
                  >
                    {netTotal >= 0 ? `+₹${netTotal.toFixed(2)}` : `-₹${Math.abs(netTotal).toFixed(2)}`}
                  </Text>
                </View>
              </View>

              <Text style={[styles.mainBalance, { color: theme.text }]}>
                {netTotal >= 0 ? `+₹${netTotal.toFixed(2)}` : `-₹${Math.abs(netTotal).toFixed(2)}`}
              </Text>

              <View style={styles.divider} />

              <View style={styles.balanceRow}>
                <View style={styles.balanceDetail}>
                  <Text style={styles.detailLabel}>YOU ARE OWED</Text>
                  <Text style={[styles.detailAmount, { color: '#10B981' }]}>
                    ₹{totalOwed.toFixed(2)}
                  </Text>
                </View>
                <View style={styles.verticalDivider} />
                <View style={styles.balanceDetail}>
                  <Text style={styles.detailLabel}>YOU OWE</Text>
                  <Text style={[styles.detailAmount, { color: '#EF4444' }]}>
                    ₹{totalOwe.toFixed(2)}
                  </Text>
                </View>
              </View>
            </View>

            {/* Quick Action Buttons */}
            <View style={styles.quickActions}>
              <TouchableOpacity
                style={styles.actionBtnPrimary}
                activeOpacity={0.8}
                onPress={() => setAddExpenseVisible(true)}
              >
                <Text style={styles.actionBtnIcon}>➕</Text>
                <Text style={styles.actionBtnPrimaryText}>Add Expense</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[
                  styles.actionBtnSecondary,
                  { backgroundColor: theme.backgroundElement },
                ]}
                activeOpacity={0.8}
                onPress={() => router.push('/scan' as any)}
              >
                <Text style={styles.actionBtnIcon}>📷</Text>
                <Text style={[styles.actionBtnSecondaryText, { color: theme.text }]}>
                  Scan QR
                </Text>
              </TouchableOpacity>
            </View>

            {/* Dynamic Event Cohorts Section */}
            <View style={styles.sectionHeader}>
              <ThemedText type="subtitle" style={styles.sectionTitle}>
                Event Cohorts
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

            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.groupsContainer}
            >
              {cohorts.map((cohort) => {
                const cohortM = members[cohort.id] || [];
                const cohortE = expenses[cohort.id] || [];
                const res = calculateSimplifiedDebts(cohort.id, cohortM, cohortE);
                const userBal = res.netBalances[currentUser.id] || 0;

                return (
                  <TouchableOpacity
                    key={cohort.id}
                    style={[
                      styles.groupCard,
                      { backgroundColor: theme.backgroundElement },
                    ]}
                    activeOpacity={0.8}
                    onPress={() => router.push(`/event/${cohort.id}` as any)}
                  >
                    <CategoryIcon
                      category={cohort.category}
                      customIcon={cohort.customIcon}
                      size={36}
                    />
                    <Text style={[styles.groupName, { color: theme.text }]} numberOfLines={1}>
                      {cohort.name}
                    </Text>
                    <Text style={[styles.groupMembers, { color: theme.textSecondary }]}>
                      {cohortM.length} members
                    </Text>
                    <Text
                      style={[
                        styles.groupBalance,
                        { color: userBal >= 0 ? '#10B981' : '#EF4444' },
                      ]}
                    >
                      {userBal >= 0 ? `+₹${userBal.toFixed(2)}` : `-₹${Math.abs(userBal).toFixed(2)}`}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>

            {/* Recent Ledger Activity */}
            <View style={styles.sectionHeader}>
              <ThemedText type="subtitle" style={styles.sectionTitle}>
                Recent Activity
              </ThemedText>
            </View>

            <View style={styles.expensesList}>
              {Object.values(expenses)
                .flat()
                .slice(0, 4)
                .map((item) => (
                  <View
                    key={item.id}
                    style={[
                      styles.expenseCard,
                      { backgroundColor: theme.backgroundElement },
                    ]}
                  >
                    <View style={styles.expenseIconBg}>
                      <CategoryIcon
                        category={item.category}
                        customIcon={item.customIcon}
                        size={28}
                      />
                    </View>

                    <View style={styles.expenseInfo}>
                      <Text style={[styles.expenseTitle, { color: theme.text }]}>
                        {item.title}
                      </Text>
                      <Text
                        style={[styles.expenseMeta, { color: theme.textSecondary }]}
                      >
                        Paid by {item.paidByUserId === currentUser.id ? 'You' : 'Member'} • ₹
                        {item.totalAmount}
                      </Text>
                    </View>

                    <Text style={[styles.expenseAmountText, { color: theme.text }]}>
                      ₹{item.totalAmount}
                    </Text>
                  </View>
                ))}
            </View>
      </ScrollView>

      <AddExpenseModal
        visible={addExpenseVisible}
        onClose={() => setAddExpenseVisible(false)}
      />

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
  scrollContent: {
    padding: 16,
    gap: 20,
  },
  balanceCard: {
    borderRadius: 16,
    padding: 20,
    gap: 12,
  },
  balanceHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  balanceSubTitle: {
    fontSize: 14,
    fontWeight: '500',
  },
  badge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 20,
  },
  badgeText: {
    fontWeight: '700',
    fontSize: 12,
  },
  mainBalance: {
    fontSize: 36,
    fontWeight: '800',
    letterSpacing: -1,
  },
  divider: {
    height: 1,
    backgroundColor: 'rgba(150, 150, 150, 0.15)',
    marginVertical: 4,
  },
  balanceRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    alignItems: 'center',
  },
  balanceDetail: {
    alignItems: 'center',
    gap: 4,
  },
  detailLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#8E8E93',
    letterSpacing: 0.5,
  },
  detailAmount: {
    fontSize: 18,
    fontWeight: '700',
  },
  verticalDivider: {
    width: 1,
    height: 28,
    backgroundColor: 'rgba(150, 150, 150, 0.15)',
  },
  quickActions: {
    flexDirection: 'row',
    gap: 12,
  },
  actionBtnPrimary: {
    flex: 1,
    backgroundColor: '#6366F1',
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    borderRadius: 12,
    gap: 8,
  },
  actionBtnPrimaryText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 15,
  },
  actionBtnSecondary: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 14,
    borderRadius: 12,
    gap: 8,
  },
  actionBtnSecondaryText: {
    fontWeight: '700',
    fontSize: 15,
  },
  actionBtnIcon: {
    fontSize: 16,
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
  groupsContainer: {
    gap: 12,
    paddingRight: 16,
  },
  groupCard: {
    width: 150,
    padding: 16,
    borderRadius: 14,
    gap: 6,
  },
  groupIcon: {
    fontSize: 28,
    marginBottom: 4,
  },
  groupName: {
    fontSize: 15,
    fontWeight: '700',
  },
  groupMembers: {
    fontSize: 12,
  },
  groupBalance: {
    fontSize: 14,
    fontWeight: '700',
    marginTop: 4,
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
  groupIconLarge: {
    fontSize: 32,
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
  expensesList: {
    gap: 12,
  },
  expenseCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 14,
    gap: 12,
  },
  expenseIconBg: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  expenseIcon: {
    fontSize: 22,
  },
  expenseInfo: {
    flex: 1,
    gap: 4,
  },
  expenseTitle: {
    fontSize: 15,
    fontWeight: '600',
  },
  expenseMeta: {
    fontSize: 12,
  },
  expenseAmountText: {
    fontSize: 15,
    fontWeight: '700',
  },
});

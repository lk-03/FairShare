import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  ScrollView,
  TouchableOpacity,
  Text,
  FlatList,
} from 'react-native';
import { TitleBar } from '@/components/title-bar';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { BottomTabInset } from '@/constants/theme';

interface Expense {
  id: string;
  title: string;
  category: string;
  amount: number;
  paidBy: string;
  yourShare: number;
  type: 'owed' | 'owe';
  date: string;
  icon: string;
}

interface Group {
  id: string;
  name: string;
  membersCount: number;
  balance: number;
  icon: string;
}

export default function HomeScreen() {
  const theme = useTheme();

  const [expenses] = useState<Expense[]>([
    {
      id: '1',
      title: 'Friday Night Dinner',
      category: 'Food & Dining',
      amount: 145.0,
      paidBy: 'You',
      yourShare: 72.5,
      type: 'owed',
      date: 'Today, 8:30 PM',
      icon: '🍕',
    },
    {
      id: '2',
      title: 'Groceries & Supplies',
      category: 'Home',
      amount: 84.0,
      paidBy: 'Alex',
      yourShare: 42.0,
      type: 'owe',
      date: 'Yesterday',
      icon: '🛒',
    },
    {
      id: '3',
      title: 'Uber to Airport',
      category: 'Travel',
      amount: 52.0,
      paidBy: 'You',
      yourShare: 26.0,
      type: 'owed',
      date: 'Aug 3',
      icon: '🚗',
    },
  ]);

  const [groups] = useState<Group[]>([
    { id: '1', name: 'Apartment 4B', membersCount: 3, balance: 42.0, icon: '🏠' },
    { id: '2', name: 'Weekend Trip', membersCount: 5, balance: -26.0, icon: '🏕️' },
    { id: '3', name: 'Lunch Crew', membersCount: 4, balance: 18.5, icon: '🥗' },
  ]);

  return (
    <ThemedView style={styles.container}>
      {/* Top Title Bar */}
      <TitleBar
        title="fairsharew"
        onNotificationPress={() => alert('Notifications clicked')}
        onProfilePress={() => alert('Profile clicked')}
      />

      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: BottomTabInset + 24 },
        ]}
        showsVerticalScrollIndicator={false}
      >
        {/* Balance Overview Card */}
        <View
          style={[
            styles.balanceCard,
            { backgroundColor: theme.backgroundElement },
          ]}
        >
          <View style={styles.balanceHeader}>
            <Text style={[styles.balanceSubTitle, { color: theme.textSecondary }]}>
              Total Net Balance
            </Text>
            <View style={styles.positiveBadge}>
              <Text style={styles.positiveBadgeText}>+$82.50</Text>
            </View>
          </View>

          <Text style={[styles.mainBalance, { color: theme.text }]}>
            +$82.50
          </Text>

          <View style={styles.divider} />

          <View style={styles.balanceRow}>
            <View style={styles.balanceDetail}>
              <Text style={styles.detailLabel}>YOU ARE OWED</Text>
              <Text style={[styles.detailAmount, { color: '#10B981' }]}>
                $124.50
              </Text>
            </View>
            <View style={styles.verticalDivider} />
            <View style={styles.balanceDetail}>
              <Text style={styles.detailLabel}>YOU OWE</Text>
              <Text style={[styles.detailAmount, { color: '#EF4444' }]}>
                $42.00
              </Text>
            </View>
          </View>
        </View>

        {/* Quick Action Buttons */}
        <View style={styles.quickActions}>
          <TouchableOpacity style={styles.actionBtnPrimary} activeOpacity={0.8}>
            <Text style={styles.actionBtnIcon}>➕</Text>
            <Text style={styles.actionBtnPrimaryText}>Add Expense</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.actionBtnSecondary,
              { backgroundColor: theme.backgroundElement },
            ]}
            activeOpacity={0.8}
          >
            <Text style={styles.actionBtnIcon}>🤝</Text>
            <Text style={[styles.actionBtnSecondaryText, { color: theme.text }]}>
              Settle Up
            </Text>
          </TouchableOpacity>
        </View>

        {/* Active Groups Section */}
        <View style={styles.sectionHeader}>
          <ThemedText type="subtitle" style={styles.sectionTitle}>
            Groups
          </ThemedText>
          <TouchableOpacity>
            <ThemedText type="linkPrimary">+ New Group</ThemedText>
          </TouchableOpacity>
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.groupsContainer}
        >
          {groups.map((group) => (
            <TouchableOpacity
              key={group.id}
              style={[
                styles.groupCard,
                { backgroundColor: theme.backgroundElement },
              ]}
              activeOpacity={0.8}
            >
              <Text style={styles.groupIcon}>{group.icon}</Text>
              <Text style={[styles.groupName, { color: theme.text }]}>
                {group.name}
              </Text>
              <Text style={[styles.groupMembers, { color: theme.textSecondary }]}>
                {group.membersCount} members
              </Text>
              <Text
                style={[
                  styles.groupBalance,
                  { color: group.balance >= 0 ? '#10B981' : '#EF4444' },
                ]}
              >
                {group.balance >= 0 ? `+$${group.balance.toFixed(2)}` : `-$${Math.abs(group.balance).toFixed(2)}`}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>

        {/* Recent Expenses List */}
        <View style={styles.sectionHeader}>
          <ThemedText type="subtitle" style={styles.sectionTitle}>
            Recent Activity
          </ThemedText>
          <TouchableOpacity>
            <ThemedText type="linkPrimary">See All</ThemedText>
          </TouchableOpacity>
        </View>

        <View style={styles.expensesList}>
          {expenses.map((item) => (
            <View
              key={item.id}
              style={[
                styles.expenseCard,
                { backgroundColor: theme.backgroundElement },
              ]}
            >
              <View style={styles.expenseIconBg}>
                <Text style={styles.expenseIcon}>{item.icon}</Text>
              </View>

              <View style={styles.expenseInfo}>
                <Text style={[styles.expenseTitle, { color: theme.text }]}>
                  {item.title}
                </Text>
                <Text
                  style={[styles.expenseMeta, { color: theme.textSecondary }]}
                >
                  Paid by {item.paidBy} • {item.date}
                </Text>
              </View>

              <View style={styles.expenseAmountCol}>
                <Text
                  style={[
                    styles.expenseAmountText,
                    { color: item.type === 'owed' ? '#10B981' : '#EF4444' },
                  ]}
                >
                  {item.type === 'owed'
                    ? `+$${item.yourShare.toFixed(2)}`
                    : `-$${item.yourShare.toFixed(2)}`}
                </Text>
                <Text
                  style={[
                    styles.expenseSubText,
                    { color: theme.textSecondary },
                  ]}
                >
                  {item.type === 'owed' ? 'you lent' : 'you owe'}
                </Text>
              </View>
            </View>
          ))}
        </View>
      </ScrollView>
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
  positiveBadge: {
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 20,
  },
  positiveBadgeText: {
    color: '#10B981',
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
    width: 140,
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
  expenseAmountCol: {
    alignItems: 'flex-end',
    gap: 2,
  },
  expenseAmountText: {
    fontSize: 15,
    fontWeight: '700',
  },
  expenseSubText: {
    fontSize: 11,
  },
});

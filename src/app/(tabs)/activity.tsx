import React, { useMemo } from 'react';
import { StyleSheet, View, ScrollView, TouchableOpacity, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { BottomTabInset } from '@/constants/theme';
import { CategoryIcon } from '@/components/ui/CategoryIcon';

// Simple relative time formatter
function formatTimeAgo(dateStr: string) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  if (days === 1) return `yesterday`;
  return `${days} days ago`;
}

export default function ActivityScreen() {
  const router = useRouter();
  const theme = useTheme();
  const { expenses, comments, cohorts, currentUser, members } = useExpenseStore();

  const activityFeed = useMemo(() => {
    let feed: any[] = [];
    
    // Process all expenses across all cohorts
    Object.entries(expenses).forEach(([cohortId, cohortExpenses]) => {
      const cohort = cohorts.find(c => c.id === cohortId);
      if (!cohort) return;

      const cohortMembers = members[cohortId] || [];

      cohortExpenses.forEach(exp => {
        // Is user involved?
        const isPayer = exp.paidByUserId === currentUser.id;
        const isSplitter = exp.splits.some(s => s.userId === currentUser.id);
        
        if (isPayer || isSplitter) {
          const memberMatch = cohortMembers.find(m => m.userId === exp.paidByUserId);
          const payerName = exp.paidByUserId === currentUser.id ? 'You' : (memberMatch?.profile?.fullName || 'Member');
          
          feed.push({
            id: `exp_${exp.id}`,
            type: 'expense',
            timestamp: new Date(exp.createdAt).getTime(),
            dateStr: exp.createdAt,
            cohortId,
            cohortName: cohort.name,
            title: exp.title,
            amount: exp.totalAmount,
            meta: `${payerName} added a new expense`,
            category: exp.category,
            customIcon: exp.customIcon,
          });
        }
      });
    });

    // Process all comments (if we want them in the feed)
    Object.entries(comments).forEach(([expenseId, expenseComments]) => {
      // Need to find which cohort this expense belongs to
      let foundCohortId = '';
      let foundExpense: import('@/types').Expense | null = null;
      Object.entries(expenses).forEach(([cid, exps]) => {
        const match = exps.find(e => e.id === expenseId);
        if (match) {
          foundCohortId = cid;
          foundExpense = match;
        }
      });

      if (foundCohortId && foundExpense) {
        const cohort = cohorts.find(c => c.id === foundCohortId);
        const cohortMembers = members[foundCohortId] || [];
        
        const expense = foundExpense as import('@/types').Expense;
        
        expenseComments.forEach(comment => {
          // If the user is involved in the expense or made the comment
          const isUserComment = comment.userId === currentUser.id;
          const isPayer = expense.paidByUserId === currentUser.id;
          const isSplitter = expense.splits.some((s: any) => s.userId === currentUser.id);

          if (isUserComment || isPayer || isSplitter) {
             const commenterMatch = cohortMembers.find(m => m.userId === comment.userId);
             const commenterName = comment.userId === currentUser.id ? 'You' : (commenterMatch?.profile?.fullName || 'Member');
             feed.push({
              id: `com_${comment.id}`,
              type: 'comment',
              timestamp: new Date(comment.createdAt).getTime(),
              dateStr: comment.createdAt,
              cohortId: foundCohortId,
              cohortName: cohort?.name || '',
              title: expense.title,
              amount: null,
              meta: `${commenterName} commented: "${comment.content}"`,
              category: 'comment',
            });
          }
        });
      }
    });

    return feed.sort((a, b) => b.timestamp - a.timestamp);
  }, [expenses, comments, cohorts, currentUser, members]);

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <ThemedText type="title">Activity</ThemedText>
      </View>

      <ScrollView
        contentContainerStyle={[styles.scrollContent, { paddingBottom: BottomTabInset + 24 }]}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.feedList}>
          {activityFeed.length === 0 ? (
            <Text style={[styles.emptyText, { color: theme.textSecondary }]}>No recent activity.</Text>
          ) : (
            activityFeed.map((item) => (
              <TouchableOpacity
                key={item.id}
                style={[
                  styles.feedCard,
                  { backgroundColor: theme.backgroundElement },
                ]}
                activeOpacity={0.8}
                onPress={() => router.push(`/event/${item.cohortId}` as any)}
              >
                <View style={styles.feedIconBg}>
                  {item.type === 'comment' ? (
                     <Text style={{ fontSize: 24 }}>💬</Text>
                  ) : (
                    <CategoryIcon
                      category={item.category}
                      customIcon={item.customIcon}
                      size={28}
                    />
                  )}
                </View>

                <View style={styles.feedInfo}>
                  <Text style={[styles.feedMeta, { color: theme.textSecondary }]}>
                    {item.meta} • {item.cohortName}
                  </Text>
                  <Text style={[styles.feedTitle, { color: theme.text }]}>
                    {item.title}
                  </Text>
                  <Text style={[styles.feedTime, { color: theme.textSecondary }]}>
                    {formatTimeAgo(item.dateStr)}
                  </Text>
                </View>

                {item.amount !== null && (
                  <Text style={[styles.feedAmountText, { color: theme.text }]}>
                    ₹{item.amount}
                  </Text>
                )}
              </TouchableOpacity>
            ))
          )}
        </View>
      </ScrollView>
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
  feedList: {
    gap: 12,
  },
  feedCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 14,
    borderRadius: 14,
    gap: 12,
  },
  feedIconBg: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  feedInfo: {
    flex: 1,
    gap: 4,
  },
  feedMeta: {
    fontSize: 12,
    fontWeight: '500',
  },
  feedTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  feedTime: {
    fontSize: 11,
  },
  feedAmountText: {
    fontSize: 16,
    fontWeight: '700',
  },
  emptyText: {
    textAlign: 'center',
    marginTop: 40,
    fontSize: 14,
  },
});

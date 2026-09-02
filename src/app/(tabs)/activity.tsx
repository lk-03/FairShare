import React, { useMemo } from 'react';
import { View, ScrollView, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { BottomTabInset } from '@/constants/theme';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';
import { Button } from '@/components/ui/Button';
import { Text } from '@/components/ui/Text';
import { ExpenseShortcut } from '@/types';

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
  const { expenses, comments, cohorts, currentUser, members, addShortcut } = useExpenseStore();

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
            rawExpense: exp,
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
    <View className="flex-1 bg-screen pt-safe">
      <View className="screen-header">
        <Text className="screen-title">Activity</Text>
      </View>

      <ScrollView
        contentContainerClassName="px-5 pb-10 gap-3"
        style={{ paddingBottom: BottomTabInset + 24 }}
        showsVerticalScrollIndicator={false}
      >
        {activityFeed.length === 0 ? (
          <Text className="text-center mt-10 text-secondary text-sm">No recent activity.</Text>
        ) : (
          activityFeed.map((item) => {
            const handleItemLongPress = () => {
              if (item.type !== 'expense' || !item.rawExpense) return;
              const exp = item.rawExpense;
              showAlert(
                item.title,
                `Amount: ₹${item.amount} • ${item.cohortName}`,
                [
                  {
                    text: 'Save as Shortcut',
                    style: 'default',
                    icon: 'bookmark-outline',
                    onPress: () => {
                      const newShortcut: ExpenseShortcut = {
                        id: `sc_${Date.now()}`,
                        cohortId: item.cohortId,
                        title: exp.title,
                        category: exp.category,
                        customIcon: exp.customIcon,
                        amount: exp.totalAmount,
                        paidByUserId: exp.paidByUserId,
                        isMultiplePayers: false,
                        splitType: exp.splitType,
                        splits: exp.splits,
                        includedMemberIds: exp.splits ? exp.splits.map((s: any) => s.userId) : undefined,
                        exactSplits: exp.splitType === 'exact' && exp.splits
                          ? Object.fromEntries(exp.splits.map((s: any) => [s.userId, String(s.amount)]))
                          : undefined,
                        percentageSplits: exp.splitType === 'percentage' && exp.splits
                          ? Object.fromEntries(exp.splits.map((s: any) => [s.userId, String(s.percentage || 0)]))
                          : undefined,
                        createdAt: new Date().toISOString(),
                      };
                      addShortcut(newShortcut);
                      showAlert('Shortcut Saved', `"${exp.title}" saved to ${item.cohortName} shortcuts!`);
                    },
                  },
                  {
                    text: 'Go to Group',
                    style: 'default',
                    icon: 'arrow-forward-outline',
                    onPress: () => router.push(`/event/${item.cohortId}` as any),
                  },
                  { text: 'Cancel', style: 'cancel', icon: 'close-outline' },
                ]
              );
            };

            return (
              <TouchableOpacity
                key={item.id}
                activeOpacity={0.8}
                className="card-item"
                onPress={() => router.push(`/event/${item.cohortId}` as any)}
                onLongPress={handleItemLongPress}
              >
                <View className="flex-row items-center gap-4 flex-1 pr-2">
                  <View className="mr-4">
                    {item.type === 'comment' ? (
                      <View className="w-12 h-12 rounded-full bg-accent-pill border border-surface items-center justify-center">
                        <Ionicons name="chatbubble-ellipses-outline" size={22} color="#38BDF8" />
                      </View>
                    ) : (
                      <CategoryIcon category={item.category} customIcon={item.customIcon} size={48} variant="solid" />
                    )}
                  </View>

                  <View className="flex-1 gap-1">
                    <Text className="text-[12px] font-medium text-secondary leading-tight">
                      {item.meta} • {item.cohortName}
                    </Text>
                    <Text className="text-base font-bold text-main leading-tight">
                      {item.title}
                    </Text>
                    <Text className="text-[11px] text-secondary">
                      {formatTimeAgo(item.dateStr)}
                    </Text>
                  </View>
                </View>

                {item.amount !== null && (
                  <Text className="text-base font-extrabold text-main">
                    ₹{item.amount}
                  </Text>
                )}
              </TouchableOpacity>
            );
          })
        )}
      </ScrollView>
    </View>
  );
}

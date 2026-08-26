import React, { useMemo } from 'react';
import { View, ScrollView } from 'react-native';
import { EventCohort, Expense } from '@/types';
import { Text } from '@/components/ui/Text';

interface MonthlySpendingsTabProps {
  cohort: EventCohort;
  expenses: Expense[];
  currentUserId: string;
}

export function MonthlySpendingsTab({
  cohort,
  expenses,
  currentUserId,
}: MonthlySpendingsTabProps) {
  // Aggregate monthly spending starting from group creation month to current month
  const monthlyData = useMemo(() => {
    const creationDate = new Date(cohort.createdAt || Date.now());
    const now = new Date();

    const startYear = creationDate.getFullYear();
    const startMonth = creationDate.getMonth(); // 0-indexed

    const endYear = now.getFullYear();
    const endMonth = now.getMonth();

    const monthsList: { key: string; label: string; groupTotal: number; userTotal: number }[] = [];

    let curY = startYear;
    let curM = startMonth;

    while (curY < endYear || (curY === endYear && curM <= endMonth)) {
      const monthDate = new Date(curY, curM, 1);
      const label = monthDate.toLocaleDateString('en-US', { month: 'short', year: '2-digit' });
      const key = `${curY}-${String(curM + 1).padStart(2, '0')}`;

      monthsList.push({ key, label, groupTotal: 0, userTotal: 0 });

      curM++;
      if (curM > 11) {
        curM = 0;
        curY++;
      }
    }

    // Populate expenses into months
    expenses.forEach((exp) => {
      const expDate = new Date(exp.createdAt);
      const expKey = `${expDate.getFullYear()}-${String(expDate.getMonth() + 1).padStart(2, '0')}`;

      const targetMonth = monthsList.find((m) => m.key === expKey);
      if (targetMonth) {
        targetMonth.groupTotal += exp.totalAmount;

        const userSplit = exp.splits.find((s) => s.userId === currentUserId);
        if (userSplit) {
          targetMonth.userTotal += userSplit.amount;
        }
      }
    });

    const maxVal = Math.max(...monthsList.map((m) => Math.max(m.groupTotal, m.userTotal)), 1);

    return { monthsList, maxVal };
  }, [cohort, expenses, currentUserId]);

  const grandTotalGroup = monthlyData.monthsList.reduce((acc, m) => acc + m.groupTotal, 0);
  const grandTotalUser = monthlyData.monthsList.reduce((acc, m) => acc + m.userTotal, 0);
  const avgMonthly = Math.round((grandTotalGroup / Math.max(monthlyData.monthsList.length, 1)) * 100) / 100;

  return (
    <View className="gap-4 mt-1">
      {/* Monthly Summary Cards */}
      <View className="flex-row gap-3">
        <View className="flex-1 border border-slate-200 rounded-2xl p-3 bg-white shadow-sm items-center">
          <Text className="text-[9px] font-bold text-slate-400 uppercase tracking-widest mb-1">TOTAL GROUP SPEND</Text>
          <Text className="text-sm font-extrabold text-indigo-600">₹{grandTotalGroup.toFixed(2)}</Text>
        </View>

        <View className="flex-1 border border-slate-200 rounded-2xl p-3 bg-white shadow-sm items-center">
          <Text className="text-[9px] font-bold text-slate-400 uppercase tracking-widest mb-1">YOUR SHARE</Text>
          <Text className="text-sm font-extrabold text-emerald-600">₹{grandTotalUser.toFixed(2)}</Text>
        </View>

        <View className="flex-1 border border-slate-200 rounded-2xl p-3 bg-white shadow-sm items-center">
          <Text className="text-[9px] font-bold text-slate-400 uppercase tracking-widest mb-1">AVG MONTHLY</Text>
          <Text className="text-sm font-extrabold text-slate-900">₹{avgMonthly.toFixed(2)}</Text>
        </View>
      </View>

      {/* Monthly Spendings Combined Bar Graph */}
      <View className="card-main p-5 gap-4">
        <View className="flex-row items-center justify-between">
          <Text className="text-base font-bold text-slate-900">
            Monthly Spendings Comparison
          </Text>
          <View className="flex-row gap-3 items-center">
            <View className="flex-row items-center gap-1.5">
              <View className="w-2.5 h-2.5 rounded-full bg-slate-900" />
              <Text className="text-xs text-slate-500 font-medium">Group</Text>
            </View>
            <View className="flex-row items-center gap-1.5">
              <View className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
              <Text className="text-xs text-slate-500 font-medium">You</Text>
            </View>
          </View>
        </View>

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-5 items-end pt-4 pb-2">
          {monthlyData.monthsList.map((m) => {
            const groupBarHeight = Math.round((m.groupTotal / monthlyData.maxVal) * 120);
            const userBarHeight = Math.round((m.userTotal / monthlyData.maxVal) * 120);

            return (
              <View key={m.key} className="items-center gap-2">
                <View className="flex-row items-end gap-1.5 h-36">
                  {/* Group Bar */}
                  <View className="items-center justify-end w-6">
                    <Text className="text-[9px] font-bold text-slate-400 mb-1">
                      {m.groupTotal > 0 ? `₹${Math.round(m.groupTotal)}` : ''}
                    </Text>
                    <View
                      className="w-4 rounded-t-md bg-slate-900"
                      style={{ height: Math.max(groupBarHeight, 4) }}
                    />
                  </View>

                  {/* User Share Bar */}
                  <View className="items-center justify-end w-6">
                    <Text className="text-[9px] font-bold text-slate-400 mb-1">
                      {m.userTotal > 0 ? `₹${Math.round(m.userTotal)}` : ''}
                    </Text>
                    <View
                      className="w-4 rounded-t-md bg-emerald-500"
                      style={{ height: Math.max(userBarHeight, 4) }}
                    />
                  </View>
                </View>

                <Text className="text-xs font-bold text-slate-700">{m.label}</Text>
              </View>
            );
          })}
        </ScrollView>
      </View>
    </View>
  );
}

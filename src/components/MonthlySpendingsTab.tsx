import React, { useMemo } from 'react';
import { StyleSheet, View, Text, ScrollView } from 'react-native';
import { useTheme } from '@/hooks/use-theme';
import { EventCohort, Expense } from '@/types';

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
  const theme = useTheme();

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
    <View style={styles.container}>
      {/* Monthly Summary Cards */}
      <View style={styles.metricsRow}>
        <View style={[styles.metricCard, { backgroundColor: theme.backgroundElement }]}>
          <Text style={[styles.metricLabel, { color: theme.textSecondary }]}>TOTAL GROUP SPEND</Text>
          <Text style={[styles.metricValue, { color: '#6366F1' }]}>₹{grandTotalGroup.toFixed(2)}</Text>
        </View>

        <View style={[styles.metricCard, { backgroundColor: theme.backgroundElement }]}>
          <Text style={[styles.metricLabel, { color: theme.textSecondary }]}>YOUR CUMULATIVE SHARE</Text>
          <Text style={[styles.metricValue, { color: '#10B981' }]}>₹{grandTotalUser.toFixed(2)}</Text>
        </View>

        <View style={[styles.metricCard, { backgroundColor: theme.backgroundElement }]}>
          <Text style={[styles.metricLabel, { color: theme.textSecondary }]}>AVG MONTHLY SPEND</Text>
          <Text style={[styles.metricValue, { color: theme.text }]}>₹{avgMonthly.toFixed(2)}</Text>
        </View>
      </View>

      {/* Monthly Spendings Combined Bar Graph */}
      <View style={[styles.chartCard, { backgroundColor: theme.backgroundElement }]}>
        <View style={styles.chartHeader}>
          <Text style={[styles.chartTitle, { color: theme.text }]}>
            Monthly Spendings Comparison
          </Text>
          <View style={styles.legendRow}>
            <View style={styles.legendItem}>
              <View style={[styles.legendDot, { backgroundColor: '#6366F1' }]} />
              <Text style={[styles.legendText, { color: theme.textSecondary }]}>Group Total</Text>
            </View>
            <View style={styles.legendItem}>
              <View style={[styles.legendDot, { backgroundColor: '#10B981' }]} />
              <Text style={[styles.legendText, { color: theme.textSecondary }]}>Your Share</Text>
            </View>
          </View>
        </View>

        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.barScroll}>
          {monthlyData.monthsList.map((m) => {
            const groupBarHeight = Math.round((m.groupTotal / monthlyData.maxVal) * 120);
            const userBarHeight = Math.round((m.userTotal / monthlyData.maxVal) * 120);

            return (
              <View key={m.key} style={styles.barColumn}>
                <View style={styles.barPairContainer}>
                  {/* Group Bar */}
                  <View style={styles.singleBarWrapper}>
                    <Text style={[styles.barAmtText, { color: theme.textSecondary }]}>
                      {m.groupTotal > 0 ? `₹${Math.round(m.groupTotal)}` : ''}
                    </Text>
                    <View
                      style={[
                        styles.barFill,
                        { height: Math.max(groupBarHeight, 4), backgroundColor: '#6366F1' },
                      ]}
                    />
                  </View>

                  {/* User Share Bar */}
                  <View style={styles.singleBarWrapper}>
                    <Text style={[styles.barAmtText, { color: theme.textSecondary }]}>
                      {m.userTotal > 0 ? `₹${Math.round(m.userTotal)}` : ''}
                    </Text>
                    <View
                      style={[
                        styles.barFill,
                        { height: Math.max(userBarHeight, 4), backgroundColor: '#10B981' },
                      ]}
                    />
                  </View>
                </View>

                <Text style={[styles.monthLabel, { color: theme.text }]}>{m.label}</Text>
              </View>
            );
          })}
        </ScrollView>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 14,
    marginTop: 4,
  },
  metricsRow: {
    flexDirection: 'row',
    gap: 8,
  },
  metricCard: {
    flex: 1,
    padding: 12,
    borderRadius: 12,
    gap: 4,
  },
  metricLabel: {
    fontSize: 9,
    fontWeight: '800',
    letterSpacing: 0.5,
  },
  metricValue: {
    fontSize: 15,
    fontWeight: '800',
  },
  chartCard: {
    padding: 16,
    borderRadius: 16,
    gap: 16,
  },
  chartHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  chartTitle: {
    fontSize: 15,
    fontWeight: '700',
  },
  legendRow: {
    flexDirection: 'row',
    gap: 12,
  },
  legendItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  legendDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  legendText: {
    fontSize: 11,
    fontWeight: '600',
  },
  barScroll: {
    gap: 18,
    alignItems: 'flex-end',
    paddingTop: 16,
    paddingBottom: 8,
  },
  barColumn: {
    alignItems: 'center',
    gap: 8,
  },
  barPairContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: 4,
    height: 140,
  },
  singleBarWrapper: {
    alignItems: 'center',
    justifyContent: 'flex-end',
    width: 24,
  },
  barAmtText: {
    fontSize: 9,
    fontWeight: '700',
    marginBottom: 4,
  },
  barFill: {
    width: 18,
    borderTopLeftRadius: 4,
    borderTopRightRadius: 4,
  },
  monthLabel: {
    fontSize: 11,
    fontWeight: '700',
  },
});

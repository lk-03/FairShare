import React, { useMemo } from 'react';
import { View, ScrollView, useColorScheme } from 'react-native';
import Svg, { G, Path, Circle } from 'react-native-svg';
import { Ionicons } from '@expo/vector-icons';
import { EventCohort, Expense, GroupMember } from '@/types';
import { Text } from '@/components/ui/Text';
import { CHART_PALETTE } from '@/constants/theme';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';

interface MonthlySpendingsTabProps {
  cohort: EventCohort;
  expenses: Expense[];
  currentUserId: string;
  members?: GroupMember[];
}

export function MonthlySpendingsTab({
  cohort,
  expenses,
  currentUserId,
  members = [],
}: MonthlySpendingsTabProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));
  // 1. Calculate per-member spending (share incurred vs money paid upfront)
  const stats = useMemo(() => {
    let grandTotalGroup = 0;
    let grandTotalUser = 0;

    // Collect all participant IDs from members and expenses
    const userMap: Record<
      string,
      {
        userId: string;
        name: string;
        avatarUrl?: string;
        shareAmount: number; // Consumption share
        paidAmount: number; // Upfront paid cash
        isCurrentUser: boolean;
      }
    > = {};

    // Seed members from group
    members.forEach((m) => {
      const isMe = m.userId === currentUserId;
      userMap[m.userId] = {
        userId: m.userId,
        name: m.profile?.fullName || (isMe ? 'You' : 'Member'),
        avatarUrl: m.profile?.avatarUrl,
        shareAmount: 0,
        paidAmount: 0,
        isCurrentUser: isMe,
      };
    });

    // Populate from expenses
    expenses.forEach((exp) => {
      grandTotalGroup += exp.totalAmount;

      // Track who paid upfront
      if (!userMap[exp.paidByUserId]) {
        userMap[exp.paidByUserId] = {
          userId: exp.paidByUserId,
          name: exp.paidByUserId === currentUserId ? 'You' : 'Member',
          shareAmount: 0,
          paidAmount: 0,
          isCurrentUser: exp.paidByUserId === currentUserId,
        };
      }
      userMap[exp.paidByUserId].paidAmount += exp.totalAmount;

      // Track split distribution (shares)
      exp.splits.forEach((s) => {
        if (!userMap[s.userId]) {
          userMap[s.userId] = {
            userId: s.userId,
            name: s.userId === currentUserId ? 'You' : 'Member',
            shareAmount: 0,
            paidAmount: 0,
            isCurrentUser: s.userId === currentUserId,
          };
        }
        userMap[s.userId].shareAmount += s.amount;
        if (s.userId === currentUserId) {
          grandTotalUser += s.amount;
        }
      });
    });

    const userList = Object.values(userMap);

    // Pie chart slices based on member share amounts
    const slices = userList
      .filter((u) => u.shareAmount > 0)
      .map((u, index) => {
        const color = CHART_PALETTE[index % CHART_PALETTE.length];
        const percentage = grandTotalGroup > 0 ? (u.shareAmount / grandTotalGroup) * 100 : 0;
        return {
          ...u,
          color,
          percentage,
        };
      })
      .sort((a, b) => b.shareAmount - a.shareAmount);

    // Top Spender (most cash paid upfront for group)
    const topPayer = [...userList].sort((a, b) => b.paidAmount - a.paidAmount)[0] || null;

    // Highest Consumer (most incurred share of expenses)
    const topConsumer = [...userList].sort((a, b) => b.shareAmount - a.shareAmount)[0] || null;

    return {
      grandTotalGroup,
      grandTotalUser,
      slices,
      topPayer: topPayer && topPayer.paidAmount > 0 ? topPayer : null,
      topConsumer: topConsumer && topConsumer.shareAmount > 0 ? topConsumer : null,
    };
  }, [cohort, expenses, currentUserId, members]);

  // 2. SVG Donut Arc Math
  const donutArcs = useMemo(() => {
    const size = 150;
    const cx = size / 2;
    const cy = size / 2;
    const r = 65;
    const innerR = 45;

    if (stats.grandTotalGroup === 0 || stats.slices.length === 0) {
      return { size, cx, cy, r, innerR, paths: [], isSingle: false };
    }

    if (stats.slices.length === 1) {
      return {
        size,
        cx,
        cy,
        r,
        innerR,
        paths: [],
        isSingle: true,
        singleColor: stats.slices[0].color,
      };
    }

    let currentAngle = -Math.PI / 2;
    const paths = stats.slices.map((slice) => {
      const angle = (slice.shareAmount / stats.grandTotalGroup) * 2 * Math.PI;
      const startAngle = currentAngle;
      const endAngle = currentAngle + angle;
      currentAngle = endAngle;

      const x1 = cx + r * Math.cos(startAngle);
      const y1 = cy + r * Math.sin(startAngle);
      const x2 = cx + r * Math.cos(endAngle);
      const y2 = cy + r * Math.sin(endAngle);
      const x3 = cx + innerR * Math.cos(endAngle);
      const y3 = cy + innerR * Math.sin(endAngle);
      const x4 = cx + innerR * Math.cos(startAngle);
      const y4 = cy + innerR * Math.sin(startAngle);

      const largeArcFlag = angle > Math.PI ? 1 : 0;
      const d = `M ${x1} ${y1} A ${r} ${r} 0 ${largeArcFlag} 1 ${x2} ${y2} L ${x3} ${y3} A ${innerR} ${innerR} 0 ${largeArcFlag} 0 ${x4} ${y4} Z`;

      return {
        ...slice,
        d,
      };
    });

    return { size, cx, cy, r, innerR, paths, isSingle: false };
  }, [stats]);

  return (
    <View className="gap-4 mt-1">
      {/* 3 Summary Metric Cards (Themed with NativeWind) */}
      <View className="flex-row gap-2.5">
        <View className="flex-1 bg-surface border border-surface rounded-2xl p-3 items-center shadow-sm">
          <Text className="text-[9px] font-semibold text-secondary uppercase tracking-wider mb-1" numberOfLines={1}>
            TOTAL GROUP SPEND
          </Text>
          <Text className="text-sm font-semibold text-sky-400" numberOfLines={1}>
            ₹{stats.grandTotalGroup.toFixed(2)}
          </Text>
        </View>

        <View className="flex-1 bg-surface border border-surface rounded-2xl p-3 items-center shadow-sm">
          <Text className="text-[9px] font-semibold text-secondary uppercase tracking-wider mb-1" numberOfLines={1}>
            YOUR SHARE
          </Text>
          <Text className="text-sm font-semibold text-emerald-400" numberOfLines={1}>
            ₹{stats.grandTotalUser.toFixed(2)}
          </Text>
        </View>

        <View className="flex-1 bg-surface border border-surface rounded-2xl p-3 items-center shadow-sm">
          <Text className="text-[9px] font-semibold text-secondary uppercase tracking-wider mb-1" numberOfLines={1}>
            ACTIVE MEMBERS
          </Text>
          <Text className="text-sm font-semibold text-main" numberOfLines={1}>
            {members.length > 0 ? `${members.length} members` : '1 member'}
          </Text>
        </View>
      </View>

      {/* Main Spending Pie Chart Card */}
      <View className="card-main p-5 gap-4">
        <View className="flex-row items-center justify-between">
          <Text className="text-base font-bold text-main">Spending by Person</Text>
          <View className="bg-accent-pill px-2.5 py-1 rounded-full border border-surface">
            <Text className="text-[10px] font-semibold text-secondary lowercase">
              {stats.slices.length} {stats.slices.length === 1 ? 'participant' : 'participants'}
            </Text>
          </View>
        </View>

        {stats.grandTotalGroup === 0 || stats.slices.length === 0 ? (
          <View className="py-8 items-center justify-center gap-2">
            <Ionicons name="pie-chart-outline" size={40} color="#64748B" />
            <Text className="text-xs font-semibold text-secondary text-center">
              No expenses recorded yet to generate spending breakdown.
            </Text>
          </View>
        ) : (
          <View className="gap-5">
            {/* Chart + Inline Donut Overview */}
            <View className="flex-row items-center justify-center gap-5 py-2">
              <View className="relative w-[150px] h-[150px] items-center justify-center">
                <Svg width={donutArcs.size} height={donutArcs.size}>
                  <G>
                    {donutArcs.isSingle ? (
                      <Circle
                        cx={donutArcs.cx}
                        cy={donutArcs.cy}
                        r={(donutArcs.r + donutArcs.innerR) / 2}
                        stroke={donutArcs.singleColor || '#38BDF8'}
                        strokeWidth={donutArcs.r - donutArcs.innerR}
                        fill="none"
                      />
                    ) : (
                      donutArcs.paths.map((p, i) => (
                        <Path
                          key={i}
                          d={p.d}
                          fill={p.color}
                          stroke={colors.surface}
                          strokeWidth={2}
                        />
                      ))
                    )}
                  </G>
                </Svg>

                {/* Donut Hole Total Display */}
                <View className="absolute items-center justify-center pointer-events-none">
                  <Text className="text-xs font-semibold text-main" numberOfLines={1}>
                    ₹{stats.grandTotalGroup >= 100000
                      ? `${(stats.grandTotalGroup / 1000).toFixed(0)}k`
                      : Math.round(stats.grandTotalGroup)}
                  </Text>
                  <Text className="text-[8px] font-semibold text-secondary uppercase tracking-widest mt-0.5">
                    TOTAL
                  </Text>
                </View>
              </View>

              {/* Side Legends Column with All Participants, Amount & Percentage */}
              <View className="flex-1 gap-2">
                {stats.slices.map((slice, idx) => (
                  <View
                    key={idx}
                    className="flex-row items-center justify-between bg-accent-pill/70 px-3 py-2 rounded-xl border border-surface"
                  >
                    <View className="flex-row items-center gap-2 flex-1 pr-2">
                      <View
                        className="w-2.5 h-2.5 rounded-full"
                        style={{ backgroundColor: slice.color }}
                      />
                      <Text
                        className="text-xs font-semibold text-main flex-1"
                        numberOfLines={1}
                      >
                        {slice.name}{slice.isCurrentUser ? ' (You)' : ''}
                      </Text>
                    </View>
                    <View className="items-end">
                      <Text className="text-xs font-bold text-main" numberOfLines={1}>
                        ₹{slice.shareAmount.toFixed(0)}
                      </Text>
                      <Text className="text-[10px] font-semibold text-secondary" numberOfLines={1}>
                        {slice.percentage.toFixed(0)}%
                      </Text>
                    </View>
                  </View>
                ))}
              </View>
            </View>
          </View>
        )}
      </View>

      {/* Bottom Spend Statistics Cards */}
      <View className="card-main p-4 gap-3">
        <Text className="text-sm font-semibold text-main">Group Spend Highlights</Text>

        <View className="gap-2.5">
          {/* Most Spender (Overall money paid upfront) */}
          <View className="flex-row items-center justify-between p-3 rounded-xl bg-accent-pill border border-surface">
            <View className="flex-row items-center gap-2.5 flex-1 pr-2">
              <View className="w-8 h-8 rounded-lg bg-sky-500/15 border border-sky-500/30 items-center justify-center">
                <Ionicons name="card-outline" size={16} color="#38BDF8" />
              </View>
              <View className="flex-1">
                <Text className="text-[10px] font-semibold text-secondary uppercase tracking-wider" numberOfLines={1}>
                  TOP SPENDER (PAID UPFRONT)
                </Text>
                <Text className="text-xs font-semibold text-main mt-0.5" numberOfLines={1}>
                  {stats.topPayer ? stats.topPayer.name : 'No payments yet'}
                </Text>
              </View>
            </View>
            {stats.topPayer && (
              <Text className="text-xs font-semibold text-sky-400" numberOfLines={1}>
                ₹{stats.topPayer.paidAmount.toFixed(2)} paid
              </Text>
            )}
          </View>

          {/* Most Spent Person (Highest consumption share) */}
          <View className="flex-row items-center justify-between p-3 rounded-xl bg-accent-pill border border-surface">
            <View className="flex-row items-center gap-2.5 flex-1 pr-2">
              <View className="w-8 h-8 rounded-lg bg-emerald-500/15 border border-emerald-500/30 items-center justify-center">
                <Ionicons name="pie-chart-outline" size={16} color="#34D399" />
              </View>
              <View className="flex-1">
                <Text className="text-[10px] font-semibold text-secondary uppercase tracking-wider" numberOfLines={1}>
                  HIGHEST SHARE (MOST INCURRED)
                </Text>
                <Text className="text-xs font-semibold text-main mt-0.5" numberOfLines={1}>
                  {stats.topConsumer ? stats.topConsumer.name : 'No expenses yet'}
                </Text>
              </View>
            </View>
            {stats.topConsumer && (
              <Text className="text-xs font-semibold text-emerald-400" numberOfLines={1}>
                ₹{stats.topConsumer.shareAmount.toFixed(2)} share
              </Text>
            )}
          </View>
        </View>
      </View>
    </View>
  );
}

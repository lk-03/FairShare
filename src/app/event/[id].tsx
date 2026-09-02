import React, { useState, useMemo, useRef } from 'react';
import {
  View,
  ScrollView,
  TouchableOpacity,
  Alert,
  Modal,
  Image,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { launchUPIIntent } from '@/services/payment/upiIntent';
import { QRCodeModal } from '@/components/QRCodeModal';
import { AddExpenseModal } from '@/components/AddExpenseModal';
import { EditGroupModal } from '@/components/EditGroupModal';
import { MonthlySpendingsTab } from '@/components/MonthlySpendingsTab';
import { NeedsListTab } from '@/components/NeedsListTab';
import { CategoryIcon, getCategoryMetadata } from '@/components/ui/CategoryIcon';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { Ionicons } from '@expo/vector-icons';
import { BottomTabInset } from '@/constants/theme';
import { DirectDebt, Expense, ExpenseShortcut, GroupMember, UserProfile } from '@/types';
import { ExpenseDetailsModal } from '@/components/ExpenseDetailsModal';
import { MemberProfileModal } from '@/components/MemberProfileModal';
import { ItemizedReceiptModal } from '@/components/ItemizedReceiptModal';
import { SettleUpModal } from '@/components/SettleUpModal';
import { StaleNeedsReminderModal } from '@/components/StaleNeedsReminderModal';
import { SplitwiseImportModal } from '@/components/SplitwiseImportModal';
import { Text } from '@/components/ui/Text';
import { Button } from '@/components/ui/Button';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { useColorScheme, useWindowDimensions } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

export default function EventDetailScreen() {
  const systemScheme = useColorScheme();
  const { width: windowWidth } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const memberCardWidth = useMemo(() => {
    return Math.max(92, Math.floor((windowWidth - 70) / 3.35));
  }, [windowWidth]);

  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const cohortId = Array.isArray(id) ? id[0] : (id || '');

  const { cohorts, members, expenses, currentUser, addShortcut, reassignShadowMember, toggleArchiveCohort, deleteCohort, leaveCohort } = useExpenseStore();

  const [activeTab, setActiveTab] = useState<'general' | 'monthly' | 'needs'>('general');
  const [qrVisible, setQrVisible] = useState(false);
  const [addModalVisible, setAddModalVisible] = useState(false);
  const [addMenuVisible, setAddMenuVisible] = useState(false);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [splitwiseModalVisible, setSplitwiseModalVisible] = useState(false);
  const [shadowMemberToReassign, setShadowMemberToReassign] = useState<GroupMember | null>(null);
  const [pastMembersModalVisible, setPastMembersModalVisible] = useState(false);
  const [itemizedReceiptModalVisible, setItemizedReceiptModalVisible] = useState(false);
  const [selectedMemberForProfile, setSelectedMemberForProfile] = useState<GroupMember | null>(null);
  const [menuVisible, setMenuVisible] = useState(false);
  const [selectedExpenseId, setSelectedExpenseId] = useState<string | null>(null);
  const [settleDebt, setSettleDebt] = useState<DirectDebt | null>(null);
  const [visibleExpenseCount, setVisibleExpenseCount] = useState(30);

  const tabPagerRef = useRef<ScrollView>(null);
  const TABS: Array<'general' | 'monthly' | 'needs'> = ['general', 'monthly', 'needs'];

  const handleTabPress = (tab: 'general' | 'monthly' | 'needs', index: number) => {
    setActiveTab(tab);
    tabPagerRef.current?.scrollTo({ x: index * windowWidth, animated: true });
  };

  const handlePagerScrollEnd = (e: NativeSyntheticEvent<NativeScrollEvent>) => {
    const pageIndex = Math.round(e.nativeEvent.contentOffset.x / windowWidth);
    if (pageIndex >= 0 && pageIndex < TABS.length) {
      setActiveTab(TABS[pageIndex]);
    }
  };

  const cohort = cohorts.find((c) => c.id === cohortId);
  const cohortMembers = members[cohortId] || [];
  const cohortExpenses = expenses[cohortId] || [];

  const activeMembers = useMemo(
    () => cohortMembers.filter((m) => !m.isPlaceholder),
    [cohortMembers]
  );
  const shadowMembers = useMemo(
    () => cohortMembers.filter((m) => !!m.isPlaceholder),
    [cohortMembers]
  );

  const memberMap = useMemo(() => {
    const map = new Map<string, GroupMember>();
    cohortMembers.forEach((m) => map.set(m.userId, m));
    return map;
  }, [cohortMembers]);

  const getMemberDisplayName = (userId: string, profile?: UserProfile) => {
    if (userId === currentUser.id) return 'You';
    const mem = memberMap.get(userId);
    const resolved =
      profile?.fullName?.trim() ||
      profile?.nickname?.trim() ||
      mem?.profile?.fullName?.trim() ||
      mem?.profile?.nickname?.trim() ||
      profile?.username?.trim() ||
      mem?.profile?.username?.trim() ||
      mem?.originalCsvName?.trim();

    return resolved || 'Member';
  };

  const sortedExpenses = useMemo(() => {
    return [...cohortExpenses].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
    );
  }, [cohortExpenses]);

  const simplificationResult = useMemo(() => {
    return calculateSimplifiedDebts(
      cohortId,
      cohortMembers,
      sortedExpenses
    );
  }, [cohortId, cohortMembers, sortedExpenses]);

  const userNetBalance = simplificationResult.netBalances[currentUser.id] || 0;
  const selectedExpense = useMemo(() => {
    return sortedExpenses.find((e) => e.id === selectedExpenseId) || null;
  }, [sortedExpenses, selectedExpenseId]);

  const displayedExpenses = useMemo(() => {
    return sortedExpenses.slice(0, visibleExpenseCount);
  }, [sortedExpenses, visibleExpenseCount]);

  const remainingExpensesCount = Math.max(0, sortedExpenses.length - visibleExpenseCount);
  const categoryMeta = getCategoryMetadata(cohort?.category, cohort?.customIcon);

  const handleSettleUpUPI = async (debt: DirectDebt) => {
    const payeeName = debt.toProfile?.fullName || 'Payee';
    const payeeVpa = debt.toProfile?.vpaId || `${payeeName.toLowerCase().replace(/\s+/g, '')}@upi`;

    showAlert(
      'Direct UPI P2P Settlement',
      `Launch GPay / PhonePe to pay ₹${debt.amount} directly to ${payeeName} (${payeeVpa}) with 0 fees?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Open UPI App',
          style: 'default',
          onPress: async () => {
            const success = await launchUPIIntent({
              vpaId: payeeVpa,
              payeeName,
              amount: debt.amount,
              currency: 'INR',
              note: `FairShare Settlement - ${cohort?.name || 'Group'}`,
            });
            if (!success) {
              showAlert(
                'UPI Apps Not Found',
                `Could not open UPI app. You can manually pay ₹${debt.amount} to VPA: ${payeeVpa}`
              );
            }
          },
        },
      ]
    );
  };

  if (!cohort) {
    return (
      <View className="flex-1 bg-screen items-center justify-center p-6 gap-4">
        <Text className="text-secondary text-center text-base">
          Event cohort not found.
        </Text>
        <TouchableOpacity
          className="bg-main px-5 py-2.5 rounded-2xl items-center justify-center"
          onPress={() => router.back()}
        >
          <Text className="text-screen font-bold text-sm">Go Back</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View className="flex-1 bg-screen pt-safe">
      {/* Top Bar */}
      <View className="screen-header">
        <TouchableOpacity
          onPress={() => router.back()}
          className="flex-row items-center gap-1 py-1 px-2"
        >
          <Ionicons name="chevron-back" size={22} color="#94A3B8" />
          <Text className="text-base font-bold text-main">Back</Text>
        </TouchableOpacity>
        <Text className="text-lg font-bold text-main max-w-[200px]" numberOfLines={1}>
          {cohort.name}
        </Text>
        <Button
          variant="ghost"
          size="icon"
          className="btn-icon-circle"
          onPress={() => setMenuVisible(true)}
        >
          <Ionicons name="ellipsis-vertical" size={18} color="#94A3B8" />
        </Button>
      </View>

      {/* Banner Card & Sticky Sub-Tabs Bar */}
      <View className="px-5 pt-2 pb-1 gap-3">
        {/* Banner Card */}
        <View
          className="card-main p-4 rounded-3xl border shadow-sm"
          style={{
            backgroundColor: colors.surface,
            borderColor: colors.border,
          }}
        >
          <View className="flex-row items-center gap-3.5 mb-4">
            <GroupAvatar
              avatarUrl={cohort.avatarUrl || cohort.bannerUrl}
              category={cohort.category}
              customIcon={cohort.customIcon}
              size={56}
              variant="solid"
            />
            <View className="flex-1 justify-center">
              <View className="flex-row items-center justify-between gap-2">
                <Text
                  className="text-xl font-extrabold flex-1"
                  style={{ color: colors.textMain }}
                  numberOfLines={1}
                >
                  {cohort.name}
                </Text>
                <View
                  className="flex-row items-center gap-1 px-2.5 py-1 rounded-full border"
                  style={{
                    backgroundColor: `${colors.cyan}18`,
                    borderColor: `${colors.cyan}35`,
                  }}
                >
                  <Ionicons name={categoryMeta.iconName} size={12} color={colors.cyan} />
                  <Text
                    className="text-[11px] font-bold lowercase"
                    style={{ color: colors.cyan }}
                  >
                    {categoryMeta.label}
                  </Text>
                </View>
              </View>

              {cohort.description ? (
                <Text
                  className="text-xs font-medium mt-1 leading-4"
                  style={{ color: colors.textSecondary }}
                  numberOfLines={2}
                >
                  {cohort.description}
                </Text>
              ) : (
                <Text
                  className="text-xs italic mt-1"
                  style={{ color: colors.textSecondary, opacity: 0.6 }}
                >
                  No description
                </Text>
              )}
            </View>
          </View>

          <View
            className="border-t pt-3 flex-row items-center justify-between"
            style={{ borderColor: colors.border }}
          >
            <Text
              className="text-[11px] font-bold uppercase tracking-wider"
              style={{ color: colors.textSecondary }}
              numberOfLines={1}
            >
              YOUR NET POSITION
            </Text>
            <Text
              className="text-2xl font-black"
              style={{
                color:
                  userNetBalance > 0.01
                    ? '#34D399'
                    : userNetBalance < -0.01
                    ? '#FB7185'
                    : colors.textMain,
              }}
              numberOfLines={1}
            >
              {userNetBalance > 0.01
                ? `+₹${userNetBalance.toFixed(2)}`
                : userNetBalance < -0.01
                ? `-₹${Math.abs(userNetBalance).toFixed(2)}`
                : `₹0.00`}
            </Text>
          </View>
        </View>

        {/* Sub-Tabs Bar */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          className="my-0.5"
          contentContainerClassName="gap-2 pr-4"
        >
          <TouchableOpacity
            className="px-4 py-2 rounded-2xl border"
            style={{
              backgroundColor: activeTab === 'general' ? colors.cyan : colors.surface,
              borderColor: activeTab === 'general' ? colors.cyan : colors.border,
            }}
            onPress={() => handleTabPress('general', 0)}
            activeOpacity={0.75}
          >
            <Text
              className="text-xs font-bold"
              style={{
                color: activeTab === 'general' ? '#0F172A' : colors.textSecondary,
              }}
              numberOfLines={1}
            >
              General Ledger
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            className="px-4 py-2 rounded-2xl border"
            style={{
              backgroundColor: activeTab === 'monthly' ? colors.cyan : colors.surface,
              borderColor: activeTab === 'monthly' ? colors.cyan : colors.border,
            }}
            onPress={() => handleTabPress('monthly', 1)}
            activeOpacity={0.75}
          >
            <Text
              className="text-xs font-bold"
              style={{
                color: activeTab === 'monthly' ? '#0F172A' : colors.textSecondary,
              }}
              numberOfLines={1}
            >
              Monthly Spendings
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            className="px-4 py-2 rounded-2xl border"
            style={{
              backgroundColor: activeTab === 'needs' ? colors.cyan : colors.surface,
              borderColor: activeTab === 'needs' ? colors.cyan : colors.border,
            }}
            onPress={() => handleTabPress('needs', 2)}
            activeOpacity={0.75}
          >
            <Text
              className="text-xs font-bold"
              style={{
                color: activeTab === 'needs' ? '#0F172A' : colors.textSecondary,
              }}
              numberOfLines={1}
            >
              Needs / House Cart
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </View>

      {/* Horizontal Swipeable Pager for Preloaded Tabs */}
      <ScrollView
        ref={tabPagerRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        nestedScrollEnabled
        onMomentumScrollEnd={handlePagerScrollEnd}
        className="flex-1"
      >
        {/* TAB 0: General Ledger */}
        <View style={{ width: windowWidth }} className="flex-1">
          <ScrollView
            contentContainerClassName="px-5 pb-28 gap-5"
            style={{ paddingBottom: BottomTabInset + 40 }}
            showsVerticalScrollIndicator={false}
            nestedScrollEnabled
          >
            {/* Status Section */}
            <View className="section-header-row">
              <Text className="section-header-title">Status</Text>
            </View>

            {simplificationResult.simplifiedDebts.length === 0 ? (
              <View className="card-main items-center py-8">
                <Text className="text-sm font-semibold text-secondary">
                  All debts are completely settled up!
                </Text>
              </View>
            ) : (
              <View className="gap-3">
                {simplificationResult.simplifiedDebts.map((debt, index) => {
                  const isDebtor = debt.fromUserId === currentUser.id;
                  const isCreditor = debt.toUserId === currentUser.id;
                  const fromName = isDebtor ? 'You' : getMemberDisplayName(debt.fromUserId, debt.fromProfile);
                  const toName = isCreditor ? 'you' : getMemberDisplayName(debt.toUserId, debt.toProfile);
                  const hasPayeeVpa = !!(debt.toProfile?.vpaId || memberMap.get(debt.toUserId)?.profile?.vpaId);

                  let headline = '';
                  let subtitle = '';
                  let amountClass = '';
                  let amountPrefix = '';

                  if (isCreditor) {
                    headline = `${fromName} owes you`;
                    subtitle = debt.fromProfile?.username ? `@${debt.fromProfile.username}` : 'Pending settlement to you';
                    amountClass = 'text-emerald-400';
                    amountPrefix = '+';
                  } else if (isDebtor) {
                    headline = `You owe ${toName}`;
                    subtitle = debt.toProfile?.username ? `@${debt.toProfile.username}` : 'Pending settlement from you';
                    amountClass = 'text-rose-400';
                    amountPrefix = '-';
                  } else {
                    headline = `${fromName} owes ${toName}`;
                    subtitle = 'Group settlement';
                    amountClass = 'text-secondary';
                  }

                  return (
                    <View
                      key={`debt_${index}`}
                      className="card-main flex-row items-center justify-between"
                    >
                      <View className="flex-1 pr-2">
                        <View className="flex-row items-center gap-1.5">
                          <Text className="text-sm font-bold text-main" numberOfLines={1}>
                            {headline}
                          </Text>
                          {hasPayeeVpa && (
                            <Ionicons name="checkmark-circle" size={13} color={colors.cyan} />
                          )}
                        </View>
                        <Text className="text-xs text-secondary mt-0.5" numberOfLines={1}>
                          {subtitle}
                        </Text>
                      </View>

                      <View className="flex-row items-center gap-3">
                        <Text className={`text-base font-extrabold ${amountClass}`} numberOfLines={1}>
                          {amountPrefix}₹{debt.amount.toFixed(2)}
                        </Text>

                        {isDebtor && (
                          <TouchableOpacity
                            className="px-3 py-1.5 rounded-xl flex-row items-center gap-1.5 border"
                            style={{
                              backgroundColor: `${colors.cyan}18`,
                              borderColor: `${colors.cyan}40`,
                            }}
                            onPress={() => setSettleDebt(debt)}
                            activeOpacity={0.7}
                          >
                            <Ionicons name="flash-outline" size={14} color={colors.cyan} />
                            <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                              Settle UPI
                            </Text>
                          </TouchableOpacity>
                        )}
                      </View>
                    </View>
                  );
                })}
              </View>
            )}

            {/* Group Members Section */}
            <View className="section-header-row mt-4">
              <Text className="section-header-title">
                Members ({activeMembers.length}{shadowMembers.length > 0 ? ` + ${shadowMembers.length} past` : ''})
              </Text>
              {currentUser.id === cohort.createdBy && (
                <TouchableOpacity
                  onPress={() => setSplitwiseModalVisible(true)}
                  className="flex-row items-center gap-1 bg-emerald-500/10 border border-emerald-500/30 px-2.5 py-1 rounded-xl"
                  activeOpacity={0.75}
                >
                  <Ionicons name="swap-horizontal" size={13} color="#10B981" />
                  <Text className="text-[11px] font-bold text-emerald-500">Import CSV</Text>
                </TouchableOpacity>
              )}
            </View>

            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2.5 py-1">
              {activeMembers.map((m) => {
                const isCurrentUser = m.userId === currentUser.id;
                const name = isCurrentUser
                  ? 'You'
                  : (m.profile?.fullName || m.profile?.nickname || m.profile?.username || 'Member');
                const isAdmin = m.role === 'admin' || m.userId === cohort.createdBy;
                const avatarUri = isCurrentUser ? currentUser.avatarUrl : m.profile?.avatarUrl;

                return (
                  <TouchableOpacity
                    key={m.userId}
                    onPress={() => {
                      if (isCurrentUser) {
                        setSelectedMemberForProfile({
                          ...m,
                          profile: currentUser,
                        });
                      } else {
                        setSelectedMemberForProfile(m);
                      }
                    }}
                    activeOpacity={0.75}
                    className="card-main p-3 items-center gap-2"
                    style={{ width: memberCardWidth }}
                  >
                    <View className="relative">
                      <View
                        className="w-10 h-10 rounded-full items-center justify-center bg-accent-pill border border-surface overflow-hidden"
                      >
                        {avatarUri ? (
                          <Image
                            source={{ uri: avatarUri }}
                            className="w-10 h-10 rounded-full"
                          />
                        ) : (
                          <Text className="text-sm font-bold text-main">
                            {(name || 'M').charAt(0).toUpperCase()}
                          </Text>
                        )}
                      </View>
                      {isAdmin && (
                        <View
                          className="absolute -bottom-1 -right-1 rounded-full p-0.5 border border-surface"
                          style={{ backgroundColor: colors.cyan }}
                        >
                          <Ionicons name="shield-checkmark" size={10} color="#0F172A" />
                        </View>
                      )}
                    </View>

                    <View className="items-center w-full">
                      <Text className="text-xs font-bold text-main text-center w-full" numberOfLines={1}>
                        {name}
                      </Text>
                      <Text
                        className="text-[10px] font-semibold mt-0.5 text-center"
                        style={isAdmin ? { color: colors.cyan } : { color: colors.textSecondary }}
                        numberOfLines={1}
                      >
                        {isAdmin ? 'Admin' : 'Member'}
                      </Text>
                    </View>
                  </TouchableOpacity>
                );
              })}

              {/* Grouped Past / Shadow Members Card at the end */}
              {shadowMembers.length > 0 && (
                <TouchableOpacity
                  onPress={() => setPastMembersModalVisible(true)}
                  activeOpacity={0.75}
                  className="card-main p-3 items-center justify-center gap-2"
                  style={{
                    width: memberCardWidth,
                    borderStyle: 'dashed',
                    borderColor: '#F59E0B',
                  }}
                >
                  <View className="w-10 h-10 rounded-full items-center justify-center bg-amber-500/10 border border-amber-500/30">
                    <Ionicons name="people-outline" size={18} color="#F59E0B" />
                  </View>

                  <View className="items-center w-full">
                    <Text className="text-xs font-bold text-amber-500 text-center w-full" numberOfLines={1}>
                      {shadowMembers.length} Past
                    </Text>
                    <Text className="text-[10px] font-semibold text-secondary text-center mt-0.5" numberOfLines={1}>
                      Tap to view
                    </Text>
                  </View>
                </TouchableOpacity>
              )}
            </ScrollView>

            {/* History Feed */}
            <View className="section-header-row mt-4">
              <Text className="section-header-title">History</Text>
            </View>

            <View className="gap-3">
              {cohortExpenses.length === 0 ? (
                <View className="card-main items-center py-8">
                  <Text className="text-sm font-semibold text-secondary">
                    No expenses recorded yet.
                  </Text>
                </View>
              ) : (
                <>
                  {displayedExpenses.map((exp) => {
                    const isPayer = exp.paidByUserId === currentUser.id;
                    const payerMember = memberMap.get(exp.paidByUserId);
                    const payerName = isPayer
                      ? 'You'
                      : (payerMember?.profile?.fullName || payerMember?.profile?.nickname || payerMember?.originalCsvName || 'Member');

                    // Calculate net share that current user gets or owes
                    const mySplitObj = exp.splits?.find((s) => s.userId === currentUser.id);
                    const mySplit = mySplitObj ? mySplitObj.amount : 0;

                    let netText = '';
                    let netClass = '';

                    if (isPayer) {
                      const lentAmount = exp.totalAmount - mySplit;
                      if (lentAmount > 0) {
                        netText = `+₹${lentAmount.toFixed(2)}`;
                        netClass = 'text-emerald-400';
                      } else {
                        netText = `₹0.00`;
                        netClass = 'text-secondary';
                      }
                    } else {
                      if (mySplit > 0) {
                        netText = `-₹${mySplit.toFixed(2)}`;
                        netClass = 'text-rose-400';
                      } else {
                        netText = `Not involved`;
                        netClass = 'text-secondary';
                      }
                    }

                    const handleExpenseLongPress = () => {
                      showAlert(
                        exp.title,
                        `Amount: ₹${exp.totalAmount.toFixed(2)} • ${exp.category}`,
                        [
                          {
                            text: 'Save as Shortcut',
                            style: 'default',
                            icon: 'bookmark-outline',
                            onPress: () => {
                              const newShortcut: ExpenseShortcut = {
                                id: `sc_${Date.now()}`,
                                cohortId: exp.cohortId,
                                title: exp.title,
                                category: exp.category,
                                customIcon: exp.customIcon,
                                amount: exp.totalAmount,
                                paidByUserId: exp.paidByUserId,
                                isMultiplePayers: false,
                                splitType: exp.splitType,
                                splits: exp.splits,
                                includedMemberIds: exp.splits ? exp.splits.map((s) => s.userId) : undefined,
                                exactSplits: exp.splitType === 'exact' && exp.splits
                                  ? Object.fromEntries(exp.splits.map((s) => [s.userId, String(s.amount)]))
                                  : undefined,
                                percentageSplits: exp.splitType === 'percentage' && exp.splits
                                  ? Object.fromEntries(exp.splits.map((s) => [s.userId, String(s.percentage || 0)]))
                                  : undefined,
                                createdAt: new Date().toISOString(),
                              };
                              addShortcut(newShortcut);
                              showAlert('Shortcut Saved', `"${exp.title}" was saved as a quick shortcut!`);
                            },
                          },
                          {
                            text: 'View Details',
                            style: 'default',
                            icon: 'eye-outline',
                            onPress: () => setSelectedExpenseId(exp.id),
                          },
                          { text: 'Cancel', style: 'cancel', icon: 'close-outline' },
                        ]
                      );
                    };

                    return (
                      <TouchableOpacity
                        key={exp.id}
                        activeOpacity={0.8}
                        className="card-item"
                        onPress={() => setSelectedExpenseId(exp.id)}
                        onLongPress={handleExpenseLongPress}
                      >
                        <View className="flex-row items-center gap-4 flex-1 pr-3">
                          <CategoryIcon category={exp.category} customIcon={exp.customIcon} size={44} variant="solid" />
                          <View className="flex-1">
                            <Text className="text-base font-bold text-main">{exp.title}</Text>
                            <Text className="text-xs text-secondary mt-0.5">
                              Paid by {payerName} • {exp.category}
                            </Text>
                          </View>
                        </View>

                        <View className="items-end justify-center">
                          <Text className="text-base font-extrabold text-main">
                            ₹{exp.totalAmount.toFixed(2)}
                          </Text>
                          <Text className={`text-[11px] font-semibold mt-0.5 ${netClass}`}>
                            {netText}
                          </Text>
                        </View>
                      </TouchableOpacity>
                    );
                  })}

                  {remainingExpensesCount > 0 && (
                    <TouchableOpacity
                      onPress={() => setVisibleExpenseCount((prev) => prev + 50)}
                      className="p-3.5 rounded-2xl bg-accent-pill border border-surface items-center justify-center mt-1"
                      activeOpacity={0.75}
                    >
                      <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                        Show More (+{Math.min(50, remainingExpensesCount)} of {remainingExpensesCount} older expenses)
                      </Text>
                    </TouchableOpacity>
                  )}
                </>
              )}
            </View>
          </ScrollView>
        </View>

        {/* TAB 1: Monthly Spendings */}
        <View style={{ width: windowWidth }} className="flex-1">
          <ScrollView
            contentContainerClassName="px-5 pb-28 gap-5"
            style={{ paddingBottom: BottomTabInset + 40 }}
            showsVerticalScrollIndicator={false}
            nestedScrollEnabled
          >
            <MonthlySpendingsTab
              cohort={cohort}
              expenses={cohortExpenses}
              currentUserId={currentUser.id}
              members={cohortMembers}
            />
          </ScrollView>
        </View>

        {/* TAB 2: Needs / House Cart */}
        <View style={{ width: windowWidth }} className="flex-1">
          <ScrollView
            contentContainerClassName="px-5 pb-28 gap-5"
            style={{ paddingBottom: BottomTabInset + 40 }}
            showsVerticalScrollIndicator={false}
            nestedScrollEnabled
          >
            <NeedsListTab cohortId={cohort.id} />
          </ScrollView>
        </View>
      </ScrollView>

      {/* Floating Action Button (FAB) for Expanding New Transaction Options */}
      <TouchableOpacity
        className="fab-main-btn"
        style={{
          right: 20,
          bottom: 24,
        }}
        activeOpacity={0.85}
        onPress={() => setAddMenuVisible(true)}
      >
        <Ionicons name="add" size={28} color={colors.cyan} />
      </TouchableOpacity>

      {/* Expandable Action Sheet (Add Expense / Scan Receipt) */}
      <Modal
        visible={addMenuVisible}
        transparent
        animationType="fade"
        onRequestClose={() => setAddMenuVisible(false)}
      >
        <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
          <TouchableOpacity
            className="flex-1"
            activeOpacity={1}
            onPress={() => setAddMenuVisible(false)}
          />
          <View
            className="bg-surface rounded-t-[32px] p-6 gap-3.5 border-t border-border"
            style={{
              backgroundColor: colors.surface,
              borderColor: colors.border,
              paddingBottom: Math.max(insets.bottom + 16, 32),
            }}
          >
            <View className="flex-row items-center justify-between pb-2 border-b border-border">
              <Text className="text-xs font-bold uppercase tracking-wider text-secondary">
                NEW TRANSACTION
              </Text>
              <TouchableOpacity onPress={() => setAddMenuVisible(false)}>
                <Ionicons name="close" size={20} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>

            {/* Option 1: Add Expense (Manual Entry) */}
            <TouchableOpacity
              className="flex-row items-center gap-4 p-4 rounded-2xl border"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderColor: colors.border,
              }}
              activeOpacity={0.8}
              onPress={() => {
                setAddMenuVisible(false);
                setAddModalVisible(true);
              }}
            >
              <View
                className="w-12 h-12 rounded-full items-center justify-center"
                style={{
                  backgroundColor: colors.surface,
                  borderWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <Ionicons name="add" size={26} color={colors.cyan} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-extrabold text-main">Add Expense</Text>
                <Text className="text-xs text-secondary mt-0.5">
                  Manual entry with custom splits and single/multiple payers
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} />
            </TouchableOpacity>

            {/* Option 2: Scan Receipt (AI OCR) */}
            <TouchableOpacity
              className="flex-row items-center gap-4 p-4 rounded-2xl border"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderColor: colors.border,
              }}
              activeOpacity={0.8}
              onPress={() => {
                setAddMenuVisible(false);
                setItemizedReceiptModalVisible(true);
              }}
            >
              <View
                className="w-12 h-12 rounded-full items-center justify-center"
                style={{
                  backgroundColor: colors.surface,
                  borderWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <Ionicons name="receipt-outline" size={22} color={colors.cyan} />
              </View>
              <View className="flex-1">
                <Text className="text-base font-extrabold text-main">Scan Receipt</Text>
                <Text className="text-xs text-secondary mt-0.5">
                  AI OCR itemized bill extraction with Gemini Vision
                </Text>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      <QRCodeModal
        visible={qrVisible}
        onClose={() => setQrVisible(false)}
        title={cohort.name}
        inviteCode={cohort.inviteCode}
      />

      <AddExpenseModal
        visible={addModalVisible}
        onClose={() => setAddModalVisible(false)}
        cohortId={id as string}
      />

      <EditGroupModal
        visible={editModalVisible}
        onClose={() => setEditModalVisible(false)}
        cohort={cohort}
      />

      <ExpenseDetailsModal
        visible={!!selectedExpenseId}
        onClose={() => setSelectedExpenseId(null)}
        expense={selectedExpense}
        cohortMembers={cohortMembers}
        currentUser={currentUser}
      />

      <SettleUpModal
        visible={!!settleDebt}
        onClose={() => setSettleDebt(null)}
        cohortId={cohort.id}
        debt={settleDebt}
      />

      {/* Three Dot Options Menu Modal */}
      <Modal visible={menuVisible} transparent animationType="fade" onRequestClose={() => setMenuVisible(false)}>
        <View className={`flex-1 ${activeThemeClass} bg-black/50 justify-end`}>
          <TouchableOpacity
            className="flex-1"
            activeOpacity={1}
            onPress={() => setMenuVisible(false)}
          />
          <View className="bg-surface rounded-t-3xl p-6 gap-4 border-t border-surface">
            <Text className="section-label">
              GROUP OPTIONS
            </Text>

            <TouchableOpacity
              className="flex-row items-center gap-3.5 py-3"
              onPress={() => {
                setMenuVisible(false);
                setItemizedReceiptModalVisible(true);
              }}
            >
              <Ionicons name="receipt-outline" size={22} color={colors.cyan} />
              <Text className="text-base font-semibold" style={{ color: colors.cyan }}>Scan Receipt (AI Itemized OCR)</Text>
            </TouchableOpacity>

            <TouchableOpacity
              className="flex-row items-center gap-3.5 py-3"
              onPress={() => {
                setMenuVisible(false);
                setQrVisible(true);
              }}
            >
              <Ionicons name="qr-code-outline" size={22} color={colors.cyan} />
              <Text className="text-base font-semibold text-main">Invite Members (QR & Code)</Text>
            </TouchableOpacity>

            <TouchableOpacity
              className="flex-row items-center gap-3.5 py-3"
              onPress={() => {
                setMenuVisible(false);
                setEditModalVisible(true);
              }}
            >
              <Ionicons name="settings-outline" size={22} color="#94A3B8" />
              <Text className="text-base font-semibold text-main">Group Settings & Edit Info</Text>
            </TouchableOpacity>

            {currentUser.id === cohort.createdBy && (
              <TouchableOpacity
                className="flex-row items-center gap-3.5 py-3"
                onPress={() => {
                  setMenuVisible(false);
                  setSplitwiseModalVisible(true);
                }}
              >
                <Ionicons name="swap-horizontal" size={22} color="#10B981" />
                <Text className="text-base font-semibold text-emerald-400">Import Splitwise CSV History</Text>
              </TouchableOpacity>
            )}

            {/* Archive / Unarchive Group (Mute from Total Owings) */}
            <TouchableOpacity
              className="flex-row items-center gap-3.5 py-3 border-t"
              style={{ borderColor: colors.border }}
              onPress={async () => {
                setMenuVisible(false);
                const nextArchived = !cohort.isArchived;
                await toggleArchiveCohort(cohort.id);
                if (nextArchived) {
                  showAlert('Group Archived', `"${cohort.name}" is now archived. Its balance will no longer count towards your total owings, but the group remains accessible.`);
                } else {
                  showAlert('Group Unarchived', `"${cohort.name}" is now unarchived and included in your total owings.`);
                }
              }}
            >
              <Ionicons name={cohort.isArchived ? "archive" : "archive-outline"} size={22} color="#F59E0B" />
              <Text className="text-base font-semibold text-amber-400">
                {cohort.isArchived ? "Unarchive Group (Include in Totals)" : "Archive Group (Exclude from Totals)"}
              </Text>
            </TouchableOpacity>

            {(currentUser.id === cohort.createdBy || activeMembers.some(m => m.userId === currentUser.id && m.role === 'admin')) && (
              <TouchableOpacity
                className="flex-row items-center gap-3.5 py-3 border-t"
                style={{ borderColor: colors.border }}
                onPress={() => {
                  setMenuVisible(false);
                  showAlert(
                    'Delete Group',
                    `Are you sure you want to delete "${cohort.name}"?\n\nThis group will be moved to Trash for 15 days, after which it will be permanently deleted from the database. You can restore it anytime within 15 days.`,
                    [
                      {
                        text: 'Delete Group (15 Days Trash)',
                        style: 'destructive',
                        onPress: async () => {
                          await deleteCohort(cohort.id);
                          router.replace('/(tabs)/groups' as any);
                          showAlert('Moved to Trash', `"${cohort.name}" has been moved to Trash and will be permanently deleted in 15 days.`);
                        },
                      },
                      { text: 'Cancel', style: 'cancel' },
                    ]
                  );
                }}
              >
                <Ionicons name="trash-outline" size={22} color="#FB7185" />
                <Text className="text-base font-semibold text-rose-400">Delete Group</Text>
              </TouchableOpacity>
            )}

            {/* Leave Group Action (Only in multi-member groups; 1-member groups can only be deleted) */}
            {activeMembers.length > 1 && (
              <TouchableOpacity
                className="flex-row items-center gap-3.5 py-3 border-t"
                style={{ borderColor: colors.border }}
                onPress={() => {
                  setMenuVisible(false);
                  const isUserAdmin =
                    cohort.createdBy === currentUser.id ||
                    activeMembers.some((m) => m.userId === currentUser.id && m.role === 'admin');
                  const remaining = activeMembers.filter(
                    (m) => m.userId !== currentUser.id && !m.isPlaceholder
                  );
                  remaining.sort(
                    (a, b) => new Date(a.joinedAt).getTime() - new Date(b.joinedAt).getTime()
                  );
                  const nextAdminName =
                    remaining[0]?.profile?.fullName ||
                    remaining[0]?.profile?.nickname ||
                    'the next oldest member';

                  const message = isUserAdmin
                    ? `Since you are the group admin, leaving will automatically assign admin privileges to ${nextAdminName} and notify all group members. Are you sure you want to leave "${cohort.name}"?`
                    : `Are you sure you want to leave "${cohort.name}"?`;

                  showAlert('Leave Group', message, [
                    {
                      text: 'Leave Group',
                      style: 'destructive',
                      onPress: async () => {
                        const res = await leaveCohort(cohort.id);
                        router.replace('/(tabs)/groups' as any);
                        if (res.nextAdminName) {
                          showAlert(
                            'Group Left',
                            `You left the group. Admin transferred to ${res.nextAdminName}.`
                          );
                        } else {
                          showAlert('Group Left', `You have left "${cohort.name}".`);
                        }
                      },
                    },
                    { text: 'Cancel', style: 'cancel' },
                  ]);
                }}
              >
                <Ionicons name="log-out-outline" size={22} color="#FB7185" />
                <Text className="text-base font-semibold text-rose-400">Leave Group</Text>
              </TouchableOpacity>
            )}

            <TouchableOpacity
              className="items-center py-3 mt-2"
              onPress={() => setMenuVisible(false)}
            >
              <Text className="text-base font-bold text-negative">Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Splitwise History Importer Modal */}
      <SplitwiseImportModal
        visible={splitwiseModalVisible}
        onClose={() => setSplitwiseModalVisible(false)}
        targetCohort={cohort}
      />

      {/* Past / Shadow Members Bottom Sheet Modal */}
      <Modal
        visible={pastMembersModalVisible}
        transparent
        animationType="fade"
        statusBarTranslucent={true}
        onRequestClose={() => setPastMembersModalVisible(false)}
      >
        <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
          <TouchableOpacity
            className="flex-1"
            activeOpacity={1}
            onPress={() => setPastMembersModalVisible(false)}
          />
          <View
            className="bg-surface rounded-t-[32px] p-6 gap-4 border-t border-border"
            style={{ paddingBottom: Math.max(insets.bottom + 12, 32) }}
          >
            <View className="flex-row items-center justify-between">
              <View className="flex-row items-center gap-2.5">
                <View className="w-9 h-9 rounded-full bg-amber-500/20 items-center justify-center">
                  <Ionicons name="people-outline" size={18} color="#F59E0B" />
                </View>
                <View>
                  <Text className="text-base font-bold text-main">
                    Past Members ({shadowMembers.length})
                  </Text>
                  <Text className="text-xs font-semibold text-secondary">
                    Historical records from imported CSVs
                  </Text>
                </View>
              </View>
              <TouchableOpacity
                onPress={() => setPastMembersModalVisible(false)}
                className="p-1 rounded-full"
                hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
              >
                <Ionicons name="close" size={22} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>

            <Text className="text-xs font-semibold text-secondary leading-relaxed">
              {currentUser.id === cohort.createdBy
                ? 'These members are preserved from previous CSV imports. Tap any member to merge or reassign their historic expenses to an active group member:'
                : 'These members are preserved from previous CSV imports for historical record keeping.'}
            </Text>

            <ScrollView className="max-h-72 gap-2" showsVerticalScrollIndicator={false}>
              {shadowMembers.map((sm) => {
                const name =
                  sm.profile?.fullName ||
                  sm.profile?.nickname ||
                  sm.originalCsvName ||
                  'Shadow Member';

                return (
                  <TouchableOpacity
                    key={sm.userId}
                    onPress={() => {
                      if (currentUser.id === cohort.createdBy) {
                        setPastMembersModalVisible(false);
                        setShadowMemberToReassign(sm);
                      }
                    }}
                    activeOpacity={currentUser.id === cohort.createdBy ? 0.75 : 1}
                    className="p-3.5 rounded-2xl bg-accent-pill border border-surface flex-row items-center justify-between mb-2"
                    style={{
                      borderStyle: 'dashed',
                      borderColor: '#F59E0B',
                    }}
                  >
                    <View className="flex-row items-center gap-3 flex-1 pr-2">
                      <View className="w-9 h-9 rounded-full bg-amber-500/20 items-center justify-center">
                        <Ionicons name="cloud-outline" size={16} color="#F59E0B" />
                      </View>
                      <View className="flex-1">
                        <Text className="text-sm font-bold text-main" numberOfLines={1}>
                          {name}
                        </Text>
                        <Text className="text-[10px] font-semibold text-amber-500">
                          Shadow Member
                        </Text>
                      </View>
                    </View>

                    {currentUser.id === cohort.createdBy && (
                      <View className="flex-row items-center gap-1 bg-surface px-2.5 py-1 rounded-xl border border-surface">
                        <Text className="text-[11px] font-bold" style={{ color: colors.cyan }}>Reassign</Text>
                        <Ionicons name="chevron-forward" size={12} color={colors.cyan} />
                      </View>
                    )}
                  </TouchableOpacity>
                );
              })}
            </ScrollView>

            <TouchableOpacity
              onPress={() => setPastMembersModalVisible(false)}
              className="h-12 rounded-2xl items-center justify-center bg-accent-pill border border-surface mt-1"
              activeOpacity={0.8}
            >
              <Text className="text-xs font-bold text-secondary">Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Shadow Member Admin Reassignment Modal */}
      {shadowMemberToReassign && (
        <Modal
          visible={!!shadowMemberToReassign}
          transparent
          animationType="fade"
          statusBarTranslucent={true}
          onRequestClose={() => setShadowMemberToReassign(null)}
        >
          <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
            <TouchableOpacity
              className="flex-1"
              activeOpacity={1}
              onPress={() => setShadowMemberToReassign(null)}
            />
            <View
              className="bg-surface rounded-t-[32px] p-6 gap-4 border-t border-border"
              style={{ paddingBottom: Math.max(insets.bottom + 12, 32) }}
            >
              <View className="flex-row items-center justify-between">
                <View className="flex-row items-center gap-2">
                  <View className="w-8 h-8 rounded-full bg-amber-500/20 items-center justify-center">
                    <Ionicons name="cloud-outline" size={16} color="#F59E0B" />
                  </View>
                  <View>
                    <Text className="text-base font-bold text-main">
                      Reassign Shadow Member
                    </Text>
                    <Text className="text-xs font-semibold text-secondary">
                      {shadowMemberToReassign.profile?.fullName || shadowMemberToReassign.originalCsvName}
                    </Text>
                  </View>
                </View>
                <TouchableOpacity onPress={() => setShadowMemberToReassign(null)}>
                  <Ionicons name="close" size={22} color={colors.textSecondary} />
                </TouchableOpacity>
              </View>

              <Text className="text-xs font-semibold text-secondary leading-relaxed">
                As the Group Admin, you can reassign this shadow member's past expenses and balances to any active registered member in this group:
              </Text>

              <ScrollView className="max-h-60 gap-2">
                {cohortMembers
                  .filter((m) => !m.isPlaceholder && m.userId !== shadowMemberToReassign.userId)
                  .map((target) => {
                    const isTargetCurrentUser = target.userId === currentUser.id;
                    const targetDisplayName = isTargetCurrentUser
                      ? `${currentUser.fullName} (You)`
                      : target.profile?.fullName || target.profile?.nickname || 'Member';

                    return (
                      <TouchableOpacity
                        key={target.userId}
                        onPress={() => {
                          const shadowName =
                            shadowMemberToReassign.profile?.fullName ||
                            shadowMemberToReassign.originalCsvName ||
                            'Shadow Member';
                          showAlert(
                            'Confirm Member Reassignment',
                            `Reassign all historic expenses and splits from "${shadowName}" to "${targetDisplayName}"?`,
                            [
                              { text: 'Cancel', style: 'cancel' },
                              {
                                text: 'Reassign & Merge',
                                style: 'destructive',
                                onPress: () => {
                                  reassignShadowMember(
                                    cohort.id,
                                    shadowMemberToReassign.userId,
                                    target.userId
                                  );
                                  setShadowMemberToReassign(null);
                                  showAlert(
                                    'Reassigned',
                                    `Successfully merged ${shadowName} into ${targetDisplayName}.`
                                  );
                                },
                              },
                            ]
                          );
                        }}
                        className="p-3.5 rounded-2xl bg-accent-pill border border-surface flex-row items-center justify-between"
                        activeOpacity={0.75}
                      >
                        <View className="flex-row items-center gap-3">
                          <View
                            className="w-8 h-8 rounded-full items-center justify-center"
                            style={{ backgroundColor: `${colors.cyan}20` }}
                          >
                            <Ionicons name="person" size={14} color={colors.cyan} />
                          </View>
                          <Text className="text-sm font-bold text-main">
                            {targetDisplayName}
                          </Text>
                        </View>
                        <Ionicons name="swap-horizontal" size={16} color={colors.cyan} />
                      </TouchableOpacity>
                    );
                  })}
              </ScrollView>

              <TouchableOpacity
                onPress={() => setShadowMemberToReassign(null)}
                className="h-12 rounded-2xl items-center justify-center bg-accent-pill border border-surface mt-2"
              >
                <Text className="text-xs font-bold text-secondary">Cancel</Text>
              </TouchableOpacity>
            </View>
          </View>
        </Modal>
      )}

      {/* Stale Needs Reminder Modal */}
      <StaleNeedsReminderModal />

      {/* Member Profile Modal */}
      {selectedMemberForProfile && (
        <MemberProfileModal
          visible={!!selectedMemberForProfile}
          onClose={() => setSelectedMemberForProfile(null)}
          member={selectedMemberForProfile}
          cohortId={cohort.id}
          cohort={cohort}
        />
      )}

      {/* Itemized Receipt Scanner Modal */}
      {itemizedReceiptModalVisible && (
        <ItemizedReceiptModal
          visible={itemizedReceiptModalVisible}
          onClose={() => setItemizedReceiptModalVisible(false)}
          cohortId={cohort.id}
        />
      )}
    </View>
  );
}

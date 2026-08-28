import React, { useState } from 'react';
import {
  View,
  ScrollView,
  TouchableOpacity,
  Alert,
  Modal,
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
import { DirectDebt } from '@/types';
import { ExpenseDetailsModal } from '@/components/ExpenseDetailsModal';
import { StaleNeedsReminderModal } from '@/components/StaleNeedsReminderModal';
import { Text } from '@/components/ui/Text';
import { Button } from '@/components/ui/Button';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { useColorScheme } from 'react-native';

export default function EventDetailScreen() {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);

  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const cohortId = Array.isArray(id) ? id[0] : (id || '');

  const { cohorts, members, expenses, currentUser } = useExpenseStore();

  const [activeTab, setActiveTab] = useState<'general' | 'monthly' | 'needs'>('general');
  const [qrVisible, setQrVisible] = useState(false);
  const [addModalVisible, setAddModalVisible] = useState(false);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [menuVisible, setMenuVisible] = useState(false);
  const [selectedExpenseId, setSelectedExpenseId] = useState<string | null>(null);

  const cohort = cohorts.find((c) => c.id === cohortId);
  const cohortMembers = members[cohortId] || [];
  const cohortExpenses = expenses[cohortId] || [];

  const simplificationResult = calculateSimplifiedDebts(
    cohortId,
    cohortMembers,
    cohortExpenses
  );

  const userNetBalance = simplificationResult.netBalances[currentUser.id] || 0;
  const selectedExpense = cohortExpenses.find(e => e.id === selectedExpenseId) || null;
  const categoryMeta = getCategoryMetadata(cohort?.category, cohort?.customIcon);

  const handleSettleUpUPI = async (debt: DirectDebt) => {
    const payeeName = debt.toProfile?.fullName || 'Payee';
    const payeeVpa = debt.toProfile?.vpaId || `${payeeName.toLowerCase().replace(/\s+/g, '')}@upi`;

    Alert.alert(
      'Direct UPI P2P Settlement',
      `Launch GPay / PhonePe to pay ₹${debt.amount} directly to ${payeeName} (${payeeVpa}) with 0 fees?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Open UPI App',
          onPress: async () => {
            const success = await launchUPIIntent({
              vpaId: payeeVpa,
              payeeName,
              amount: debt.amount,
              currency: 'INR',
              note: `FairShare Settlement - ${cohort?.name || 'Group'}`,
            });
            if (!success) {
              Alert.alert(
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

      <ScrollView
        contentContainerClassName="px-5 pb-24 gap-5"
        style={{ paddingBottom: BottomTabInset + 40 }}
        showsVerticalScrollIndicator={false}
      >
        {/* Banner Card */}
        <View className="card-main">
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
                <Text className="text-xl font-extrabold text-main flex-1" numberOfLines={1}>
                  {cohort.name}
                </Text>
                <View className="flex-row items-center gap-1 bg-accent-pill px-2.5 py-1 rounded-full border border-surface">
                  <Ionicons name={categoryMeta.iconName} size={12} color="#94A3B8" />
                  <Text className="text-[11px] font-semibold text-secondary lowercase">
                    {categoryMeta.label}
                  </Text>
                </View>
              </View>

              {cohort.description ? (
                <Text className="text-xs text-secondary mt-1" numberOfLines={2}>
                  {cohort.description}
                </Text>
              ) : (
                <Text className="text-xs text-secondary/60 mt-1 italic">
                  No description
                </Text>
              )}
            </View>
          </View>

          <View className="border-t border-surface pt-3 flex-row items-center justify-between">
            <Text className="section-label" numberOfLines={1}>YOUR NET POSITION</Text>
            <Text
              className={`text-2xl font-extrabold ${userNetBalance >= 0 ? 'balance-positive' : 'balance-negative'}`}
              numberOfLines={1}
            >
              {userNetBalance >= 0 ? `+₹${userNetBalance.toFixed(2)}` : `-₹${Math.abs(userNetBalance).toFixed(2)}`}
            </Text>
          </View>
        </View>

        {/* Sub-Tabs Bar */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          className="my-1"
          contentContainerClassName="gap-2 pr-4"
        >
          <TouchableOpacity
            className={`px-4 py-2.5 rounded-2xl border ${
              activeTab === 'general'
                ? 'bg-main border-main'
                : 'bg-surface border-surface'
            }`}
            onPress={() => setActiveTab('general')}
          >
            <Text
              className={`text-xs font-semibold ${
                activeTab === 'general' ? 'text-screen' : 'text-secondary'
              }`}
              numberOfLines={1}
            >
              General Ledger
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            className={`px-4 py-2.5 rounded-2xl border ${
              activeTab === 'monthly'
                ? 'bg-main border-main'
                : 'bg-surface border-surface'
            }`}
            onPress={() => setActiveTab('monthly')}
          >
            <Text
              className={`text-xs font-semibold ${
                activeTab === 'monthly' ? 'text-screen' : 'text-secondary'
              }`}
              numberOfLines={1}
            >
              Monthly Spendings
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            className={`px-4 py-2.5 rounded-2xl border ${
              activeTab === 'needs'
                ? 'bg-main border-main'
                : 'bg-surface border-surface'
            }`}
            onPress={() => setActiveTab('needs')}
          >
            <Text
              className={`text-xs font-semibold ${
                activeTab === 'needs' ? 'text-screen' : 'text-secondary'
              }`}
              numberOfLines={1}
            >
              Needs / House Cart
            </Text>
          </TouchableOpacity>
        </ScrollView>

        {/* SUB TAB CONTENTS */}
        {activeTab === 'general' && (
          <>
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
                  const fromName = isDebtor ? 'You' : (debt.fromProfile?.fullName || debt.fromUserId);
                  const toName = isCreditor ? 'you' : (debt.toProfile?.fullName || debt.toUserId);

                  let headline = '';
                  let subtitle = '';
                  let amountClass = '';
                  let amountPrefix = '';

                  if (isCreditor) {
                    headline = `${fromName} owes you`;
                    subtitle = 'Pending settlement to you';
                    amountClass = 'text-emerald-400';
                    amountPrefix = '+';
                  } else if (isDebtor) {
                    headline = `You owe ${toName}`;
                    subtitle = 'Direct P2P Settlement';
                    amountClass = 'text-negative';
                    amountPrefix = '-';
                  } else {
                    headline = `${fromName} owes ${toName}`;
                    subtitle = 'Group Settlement';
                    amountClass = 'text-secondary';
                    amountPrefix = '';
                  }

                  return (
                    <View key={index} className="card-item">
                      <View className="flex-1 pr-3">
                        <Text className="text-base font-bold text-main">{headline}</Text>
                        <Text className="text-xs text-secondary mt-0.5">{subtitle}</Text>
                      </View>

                      <View className="items-end gap-1.5">
                        <Text className={`text-base font-extrabold ${amountClass}`}>
                          {amountPrefix}₹{debt.amount.toFixed(2)}
                        </Text>
                        {isDebtor && (
                          <TouchableOpacity
                            className="bg-emerald-500 px-3 py-1.5 rounded-xl items-center mt-1"
                            onPress={() => handleSettleUpUPI(debt)}
                          >
                            <Text className="text-white text-xs font-bold">Pay UPI</Text>
                          </TouchableOpacity>
                        )}
                      </View>
                    </View>
                  );
                })}
              </View>
            )}

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
                cohortExpenses.map((exp) => {
                  const isPayer = exp.paidByUserId === currentUser.id;
                  const payerMember = cohortMembers.find((m) => m.userId === exp.paidByUserId);
                  const payerName = isPayer ? 'You' : (payerMember?.profile?.fullName || 'Member');

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

                  return (
                    <TouchableOpacity
                      key={exp.id}
                      activeOpacity={0.8}
                      className="card-item"
                      onPress={() => setSelectedExpenseId(exp.id)}
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
                })
              )}
            </View>
          </>
        )}

        {activeTab === 'monthly' && (
          <MonthlySpendingsTab
            cohort={cohort}
            expenses={cohortExpenses}
            currentUserId={currentUser.id}
            members={cohortMembers}
          />
        )}

        {activeTab === 'needs' && (
          <NeedsListTab cohortId={cohort.id} />
        )}
      </ScrollView>

      {/* Floating Action Button (FAB) for Add Expense */}
      <TouchableOpacity
        className="fab-main-btn"
        style={{
          right: 20,
          bottom: 24,
        }}
        activeOpacity={0.85}
        onPress={() => setAddModalVisible(true)}
      >
        <Ionicons name="add" size={28} color="#38BDF8" />
      </TouchableOpacity>

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
                setQrVisible(true);
              }}
            >
              <Ionicons name="qr-code-outline" size={22} color="#94A3B8" />
              <Text className="text-base font-semibold text-main">Invite Members via QR</Text>
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

            <TouchableOpacity
              className="items-center py-3 mt-2"
              onPress={() => setMenuVisible(false)}
            >
              <Text className="text-base font-bold text-negative">Cancel</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Stale Needs Reminder Modal */}
      <StaleNeedsReminderModal />
    </View>
  );
}

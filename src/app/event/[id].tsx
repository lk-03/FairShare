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
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';
import { BottomTabInset } from '@/constants/theme';
import { DirectDebt } from '@/types';
import { ExpenseDetailsModal } from '@/components/ExpenseDetailsModal';
import { Text } from '@/components/ui/Text';
import { Button } from '@/components/ui/Button';

export default function EventDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();

  const { cohorts, members, expenses, currentUser } = useExpenseStore();

  const [activeTab, setActiveTab] = useState<'general' | 'monthly' | 'needs'>('general');
  const [qrVisible, setQrVisible] = useState(false);
  const [addModalVisible, setAddModalVisible] = useState(false);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [menuVisible, setMenuVisible] = useState(false);
  const [selectedExpenseId, setSelectedExpenseId] = useState<string | null>(null);

  const cohort = cohorts.find((c) => c.id === id);
  const cohortMembers = members[id as string] || [];
  const cohortExpenses = expenses[id as string] || [];

  const simplificationResult = calculateSimplifiedDebts(
    id as string,
    cohortMembers,
    cohortExpenses
  );

  const userNetBalance = simplificationResult.netBalances[currentUser.id] || 0;
  const selectedExpense = cohortExpenses.find(e => e.id === selectedExpenseId) || null;

  const handleSettleUpUPI = async (debt: DirectDebt) => {
    const payeeName = debt.toProfile?.fullName || 'Payee';
    const payeeVpa = debt.toProfile?.vpaId || `${payeeName.toLowerCase().replace(/\s+/g, '')}@upi`;

    Alert.alert(
      'Direct UPI P2P Settlement',
      `Launch GPay / PhonePe to pay ₹${debt.amount} directly to ${payeeName} (${payeeVpa}) with 0 fees?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Pay via UPI',
          onPress: async () => {
            const res = await launchUPIIntent({
              vpaId: payeeVpa,
              payeeName,
              amount: debt.amount,
              currency: 'INR',
              note: `FairShare - ${cohort?.name || 'Event Settlement'}`,
            });
            if (!res.success) {
              Alert.alert('UPI Launch Info', res.message);
            }
          },
        },
      ]
    );
  };

  if (!cohort) {
    return (
      <View className="flex-1 bg-screen items-center justify-center p-6">
        <Text className="text-secondary text-center text-base">
          Event cohort not found.
        </Text>
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
          <View className="flex-row items-center gap-3 mb-4">
            <CategoryIcon category={cohort.category} customIcon={cohort.customIcon} size={48} variant="solid" />
            <View className="flex-1">
              <Text className="section-label">{cohort.category}</Text>
              <Text className="text-2xl font-extrabold text-main">{cohort.name}</Text>
            </View>
          </View>

          <View className="border-t border-surface pt-3 flex-row items-center justify-between">
            <Text className="section-label">YOUR NET POSITION</Text>
            <Text className={`text-2xl font-extrabold ${userNetBalance >= 0 ? 'balance-positive' : 'balance-negative'}`}>
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
              className={`text-xs font-bold ${
                activeTab === 'general' ? 'text-screen' : 'text-secondary'
              }`}
            >
              📋 General Ledger
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
              className={`text-xs font-bold ${
                activeTab === 'monthly' ? 'text-screen' : 'text-secondary'
              }`}
            >
              📊 Monthly Spendings
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
              className={`text-xs font-bold ${
                activeTab === 'needs' ? 'text-screen' : 'text-secondary'
              }`}
            >
              🛒 Needs / House Cart
            </Text>
          </TouchableOpacity>
        </ScrollView>

        {/* SUB TAB CONTENTS */}
        {activeTab === 'general' && (
          <>
            {/* Simplified Settlement Matrix */}
            <View className="section-header-row">
              <Text className="section-header-title">Simplified P2P Settlements</Text>
            </View>

            {simplificationResult.simplifiedDebts.length === 0 ? (
              <View className="card-main items-center py-8">
                <Text className="text-sm font-semibold text-secondary">
                  🎉 All debts are completely settled up!
                </Text>
              </View>
            ) : (
              <View className="gap-3">
                {simplificationResult.simplifiedDebts.map((debt, index) => (
                  <View key={index} className="card-item">
                    <View className="flex-1 pr-3">
                      <Text className="text-base font-bold text-main">
                        {debt.fromProfile?.fullName || debt.fromUserId} → {debt.toProfile?.fullName || debt.toUserId}
                      </Text>
                      <Text className="text-xs text-secondary mt-0.5">
                        Direct P2P Settlement
                      </Text>
                    </View>

                    <View className="items-end gap-2">
                      <Text className="text-base font-extrabold text-negative">
                        ₹{debt.amount.toFixed(2)}
                      </Text>
                      {debt.fromUserId === currentUser.id && (
                        <TouchableOpacity
                          className="bg-emerald-500 px-3 py-1.5 rounded-xl items-center"
                          onPress={() => handleSettleUpUPI(debt)}
                        >
                          <Text className="text-white text-xs font-bold">Pay UPI</Text>
                        </TouchableOpacity>
                      )}
                    </View>
                  </View>
                ))}
              </View>
            )}

            {/* Ledger Activity Feed */}
            <View className="section-header-row mt-4">
              <Text className="section-header-title">Ledger Logs & Invoices</Text>
            </View>

            <View className="gap-3">
              {cohortExpenses.length === 0 ? (
                <View className="card-main items-center py-8">
                  <Text className="text-sm font-semibold text-secondary">
                    No expenses recorded yet.
                  </Text>
                </View>
              ) : (
                cohortExpenses.map((exp) => (
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
                          Paid by {exp.paidByUserId === currentUser.id ? 'You' : 'Member'} • {exp.category}
                        </Text>
                      </View>
                    </View>

                    <Text className="text-base font-extrabold text-main">
                      ₹{exp.totalAmount}
                    </Text>
                  </TouchableOpacity>
                ))
              )}
            </View>
          </>
        )}

        {activeTab === 'monthly' && (
          <MonthlySpendingsTab
            cohort={cohort}
            expenses={cohortExpenses}
            currentUserId={currentUser.id}
          />
        )}

        {activeTab === 'needs' && (
          <NeedsListTab cohortId={cohort.id} />
        )}
      </ScrollView>

      {/* Floating Action Button (FAB) for Add Expense */}
      <TouchableOpacity
        className="absolute right-6 bottom-8 w-14 h-14 rounded-full bg-main items-center justify-center shadow-lg"
        activeOpacity={0.85}
        onPress={() => setAddModalVisible(true)}
      >
        <Ionicons name="add" size={28} color="#FFFFFF" />
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
        <TouchableOpacity
          className="flex-1 bg-black/50 justify-end"
          activeOpacity={1}
          onPress={() => setMenuVisible(false)}
        >
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
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

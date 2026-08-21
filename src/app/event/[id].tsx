import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  ScrollView,
  TouchableOpacity,
  Text,
  Alert,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { calculateSimplifiedDebts } from '@/utils/debtSimplifier';
import { launchUPIIntent } from '@/services/payment/upiIntent';
import { QRCodeModal } from '@/components/QRCodeModal';
import { TransactionComments } from '@/components/TransactionComments';
import { AddExpenseModal } from '@/components/AddExpenseModal';
import { EditGroupModal } from '@/components/EditGroupModal';
import { MonthlySpendingsTab } from '@/components/MonthlySpendingsTab';
import { NeedsListTab } from '@/components/NeedsListTab';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';
import { Modal } from 'react-native';
import { BottomTabInset } from '@/constants/theme';
import { DirectDebt } from '@/types';
import { ExpenseDetailsModal } from '@/components/ExpenseDetailsModal';

export default function EventDetailScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const theme = useTheme();

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
      <View style={[styles.container, { backgroundColor: theme.background }]}>
        <Text style={{ color: theme.text, textAlign: 'center', marginTop: 100 }}>
          Event cohort not found.
        </Text>
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: theme.background }]}>
      {/* Top Bar */}
      <View style={[styles.topBar, { backgroundColor: theme.backgroundElement }]}>
        <TouchableOpacity style={styles.backBtn} onPress={() => router.back()}>
          <Text style={[styles.backText, { color: theme.text }]}>← Back</Text>
        </TouchableOpacity>
        <Text style={[styles.topTitle, { color: theme.text }]} numberOfLines={1}>
          {cohort.name}
        </Text>
        <TouchableOpacity style={styles.menuBtn} onPress={() => setMenuVisible(true)}>
          <Ionicons name="ellipsis-vertical" size={20} color={theme.text} />
        </TouchableOpacity>
      </View>

      <ScrollView
        contentContainerStyle={[
          styles.scrollContent,
          { paddingBottom: BottomTabInset + 30 },
        ]}
      >
        {/* Banner Card */}
        <View style={[styles.bannerCard, { backgroundColor: '#6366F1' }]}>
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 8 }}>
            <CategoryIcon category={cohort.category} customIcon={cohort.customIcon} size={44} color="rgba(255, 255, 255, 0.25)" />
            <View>
              <Text style={styles.bannerCategory}>{cohort.category.toUpperCase()}</Text>
              <Text style={styles.bannerTitle}>{cohort.name}</Text>
            </View>
          </View>

          <View style={styles.netBox}>
            <Text style={styles.netLabel}>YOUR NET POSITION</Text>
            <Text style={styles.netAmount}>
              {userNetBalance >= 0 ? `+₹${userNetBalance.toFixed(2)}` : `-₹${Math.abs(userNetBalance).toFixed(2)}`}
            </Text>
          </View>
        </View>

        {/* Horizontal Scrolling Sub-Tabs Bar */}
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.subTabsContainer}
        >
          <TouchableOpacity
            style={[
              styles.subTabBtn,
              activeTab === 'general' ? styles.subTabBtnActive : { backgroundColor: theme.backgroundElement },
            ]}
            onPress={() => setActiveTab('general')}
          >
            <Text
              style={[
                styles.subTabText,
                activeTab === 'general' ? styles.subTabTextActive : { color: theme.text },
              ]}
            >
              📋 General Ledger
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.subTabBtn,
              activeTab === 'monthly' ? styles.subTabBtnActive : { backgroundColor: theme.backgroundElement },
            ]}
            onPress={() => setActiveTab('monthly')}
          >
            <Text
              style={[
                styles.subTabText,
                activeTab === 'monthly' ? styles.subTabTextActive : { color: theme.text },
              ]}
            >
              📊 Monthly Spendings
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.subTabBtn,
              activeTab === 'needs' ? styles.subTabBtnActive : { backgroundColor: theme.backgroundElement },
            ]}
            onPress={() => setActiveTab('needs')}
          >
            <Text
              style={[
                styles.subTabText,
                activeTab === 'needs' ? styles.subTabTextActive : { color: theme.text },
              ]}
            >
              🛒 Needs / House Cart
            </Text>
          </TouchableOpacity>
        </ScrollView>

        {/* SUB TAB CONTENTS */}
        {activeTab === 'general' && (
          <>
            {/* Simplified Settlement Matrix */}
            <Text style={[styles.sectionTitle, { color: theme.text }]}>
              Simplified P2P Settlements
            </Text>

            {simplificationResult.simplifiedDebts.length === 0 ? (
              <View style={[styles.emptyBox, { backgroundColor: theme.backgroundElement }]}>
                <Text style={[styles.emptyText, { color: theme.textSecondary }]}>
                  🎉 All debts are completely settled up!
                </Text>
              </View>
            ) : (
              <View style={styles.debtList}>
                {simplificationResult.simplifiedDebts.map((debt, index) => (
                  <View
                    key={index}
                    style={[styles.debtCard, { backgroundColor: theme.backgroundElement }]}
                  >
                    <View style={styles.debtInfo}>
                      <Text style={[styles.debtNames, { color: theme.text }]}>
                        {debt.fromProfile?.fullName || debt.fromUserId} →{' '}
                        {debt.toProfile?.fullName || debt.toUserId}
                      </Text>
                      <Text style={[styles.debtSub, { color: theme.textSecondary }]}>
                        Direct P2P Settlement
                      </Text>
                    </View>

                    <View style={styles.debtRight}>
                      <Text style={styles.debtAmount}>₹{debt.amount.toFixed(2)}</Text>
                      {debt.fromUserId === currentUser.id && (
                        <TouchableOpacity
                          style={styles.upiBtn}
                          onPress={() => handleSettleUpUPI(debt)}
                        >
                          <Text style={styles.upiBtnText}>Pay UPI</Text>
                        </TouchableOpacity>
                      )}
                    </View>
                  </View>
                ))}
              </View>
            )}

            {/* Ledger Activity Feed */}
            <Text style={[styles.sectionTitle, { color: theme.text }]}>
              Ledger Logs & Invoices
            </Text>

            <View style={styles.expenseFeed}>
              {cohortExpenses.map((exp) => (
                <View
                  key={exp.id}
                  style={[styles.expenseCard, { backgroundColor: theme.backgroundElement }]}
                >
                  <TouchableOpacity
                    style={styles.expenseMain}
                    onPress={() =>
                      setSelectedExpenseId(selectedExpenseId === exp.id ? null : exp.id)
                    }
                  >
                    <View style={styles.expenseIcon}>
                      <CategoryIcon category={exp.category} customIcon={exp.customIcon} size={26} />
                    </View>

                    <View style={{ flex: 1 }}>
                      <Text style={[styles.expTitle, { color: theme.text }]}>
                        {exp.title}
                      </Text>
                      <Text style={[styles.expMeta, { color: theme.textSecondary }]}>
                        Paid by {exp.paidByUserId === currentUser.id ? 'You' : 'Member'} •{' '}
                        {exp.category}
                      </Text>
                    </View>

                    <Text style={[styles.expTotal, { color: theme.text }]}>
                      ₹{exp.totalAmount}
                    </Text>
                  </TouchableOpacity>
                </View>
              ))}
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
        <TouchableOpacity style={styles.menuBackdrop} activeOpacity={1} onPress={() => setMenuVisible(false)}>
          <View style={[styles.menuSheet, { backgroundColor: theme.backgroundElement }]}>
            <Text style={[styles.menuSheetTitle, { color: theme.textSecondary }]}>
              GROUP OPTIONS
            </Text>

            <TouchableOpacity
              style={styles.menuOptionRow}
              onPress={() => {
                setMenuVisible(false);
                setQrVisible(true);
              }}
            >
              <Ionicons name="qr-code-outline" size={20} color={theme.text} />
              <Text style={[styles.menuOptionText, { color: theme.text }]}>Invite Members via QR</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.menuOptionRow}
              onPress={() => {
                setMenuVisible(false);
                setEditModalVisible(true);
              }}
            >
              <Ionicons name="settings-outline" size={20} color={theme.text} />
              <Text style={[styles.menuOptionText, { color: theme.text }]}>Group Settings & Edit Info</Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={styles.menuCancelBtn}
              onPress={() => setMenuVisible(false)}
            >
              <Text style={styles.menuCancelText}>Cancel</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </Modal>

      {/* Floating Action Button (FAB) for Add Expense */}
      <TouchableOpacity
        style={[styles.fabBtn, { bottom: BottomTabInset + 20 }]}
        activeOpacity={0.85}
        onPress={() => setAddModalVisible(true)}
      >
        <Ionicons name="add" size={28} color="#FFFFFF" />
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 48,
    paddingBottom: 12,
  },
  backBtn: {
    padding: 6,
  },
  backText: {
    fontSize: 16,
    fontWeight: '600',
  },
  topTitle: {
    fontSize: 18,
    fontWeight: '700',
    maxWidth: 180,
  },
  qrBtn: {
    backgroundColor: '#6366F1',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  qrBtnText: {
    color: '#FFF',
    fontWeight: '800',
    fontSize: 12,
  },
  scrollContent: {
    padding: 16,
    gap: 16,
  },
  bannerCard: {
    borderRadius: 16,
    padding: 20,
    gap: 8,
  },
  bannerCategory: {
    color: 'rgba(255, 255, 255, 0.7)',
    fontWeight: '800',
    fontSize: 10,
    letterSpacing: 1,
  },
  bannerTitle: {
    color: '#FFF',
    fontSize: 24,
    fontWeight: '800',
  },
  netBox: {
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: 'rgba(255, 255, 255, 0.2)',
  },
  netLabel: {
    color: 'rgba(255, 255, 255, 0.8)',
    fontSize: 11,
    fontWeight: '700',
  },
  netAmount: {
    color: '#FFF',
    fontSize: 22,
    fontWeight: '800',
  },
  actionsRow: {
    flexDirection: 'row',
    gap: 12,
  },
  primaryAction: {
    flex: 1,
    backgroundColor: '#6366F1',
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  actionText: {
    color: '#FFF',
    fontWeight: '700',
    fontSize: 15,
  },
  secondaryAction: {
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  secondaryText: {
    fontWeight: '700',
    fontSize: 15,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    marginTop: 8,
  },
  emptyBox: {
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 14,
  },
  debtList: {
    gap: 10,
  },
  debtCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 14,
    borderRadius: 12,
  },
  debtInfo: {
    gap: 2,
  },
  debtNames: {
    fontSize: 15,
    fontWeight: '700',
  },
  debtSub: {
    fontSize: 12,
  },
  debtRight: {
    alignItems: 'flex-end',
    gap: 6,
  },
  debtAmount: {
    fontSize: 16,
    fontWeight: '800',
    color: '#EF4444',
  },
  upiBtn: {
    backgroundColor: '#10B981',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  upiBtnText: {
    color: '#FFF',
    fontWeight: '800',
    fontSize: 12,
  },
  expenseFeed: {
    gap: 10,
  },
  expenseCard: {
    padding: 14,
    borderRadius: 12,
  },
  expenseMain: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  expenseIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(99, 102, 241, 0.15)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  expTitle: {
    fontSize: 15,
    fontWeight: '700',
  },
  expMeta: {
    fontSize: 12,
  },
  expTotal: {
    fontSize: 16,
    fontWeight: '800',
  },
  detailsBox: {
    marginTop: 12,
    padding: 12,
    borderRadius: 10,
    gap: 8,
  },
  detailsHeader: {
    fontSize: 13,
    fontWeight: '700',
  },
  splitsBreakdownList: {
    gap: 6,
  },
  splitMemberRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  splitMemberName: {
    fontSize: 13,
    fontWeight: '600',
  },
  splitMemberAmt: {
    fontSize: 13,
    fontWeight: '700',
  },
  expenseNotes: {
    fontSize: 12,
    fontStyle: 'italic',
    marginTop: 2,
  },
  menuBtn: {
    padding: 8,
  },
  menuBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  menuSheet: {
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    padding: 20,
    gap: 16,
  },
  menuSheetTitle: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  menuOptionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingVertical: 12,
  },
  menuOptionText: {
    fontSize: 16,
    fontWeight: '600',
  },
  menuCancelBtn: {
    alignItems: 'center',
    paddingVertical: 12,
    marginTop: 8,
  },
  menuCancelText: {
    color: '#EF4444',
    fontWeight: '700',
    fontSize: 15,
  },
  fabBtn: {
    position: 'absolute',
    right: 20,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#6366F1',
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 6,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
  },
  subTabsContainer: {
    gap: 8,
    marginVertical: 12,
  },
  subTabBtn: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 20,
  },
  subTabBtnActive: {
    backgroundColor: '#6366F1',
  },
  subTabText: {
    fontSize: 13,
    fontWeight: '600',
  },
  subTabTextActive: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
});

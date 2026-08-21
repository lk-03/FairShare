import React from 'react';
import { StyleSheet, View, Text, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { Expense, GroupMember, UserProfile } from '@/types';
import { useTheme } from '@/hooks/use-theme';
import { Ionicons } from '@expo/vector-icons';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { TransactionComments } from '@/components/TransactionComments';
import { EditExpenseModal } from '@/components/EditExpenseModal';

interface ExpenseDetailsModalProps {
  visible: boolean;
  onClose: () => void;
  expense: Expense | null;
  cohortMembers: GroupMember[];
  currentUser: UserProfile;
}

export function ExpenseDetailsModal({
  visible,
  onClose,
  expense,
  cohortMembers,
  currentUser,
}: ExpenseDetailsModalProps) {
  const theme = useTheme();
  const [editModalVisible, setEditModalVisible] = React.useState(false);

  if (!expense) return null;

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <TouchableOpacity style={styles.modalBackdrop} activeOpacity={1} onPress={onClose}>
        <TouchableOpacity activeOpacity={1} style={[styles.modalSheet, { backgroundColor: theme.background }]}>
          {/* Header */}
          <View style={[styles.header, { backgroundColor: theme.backgroundElement }]}>
            <TouchableOpacity style={styles.closeBtn} onPress={onClose}>
              <Ionicons name="close" size={24} color={theme.text} />
            </TouchableOpacity>
            <Text style={[styles.headerTitle, { color: theme.text }]}>Payment Details</Text>
            <TouchableOpacity style={styles.closeBtn} onPress={() => setEditModalVisible(true)}>
              <Ionicons name="pencil" size={20} color={theme.text} />
            </TouchableOpacity>
          </View>

          <ScrollView contentContainerStyle={styles.scrollContent} showsVerticalScrollIndicator={false}>
            {/* Top Info */}
            <View style={styles.topInfo}>
              <View style={styles.expenseIcon}>
                <CategoryIcon category={expense.category} customIcon={expense.customIcon} size={48} />
              </View>
              <Text style={[styles.expTitle, { color: theme.text }]}>{expense.title}</Text>
              <Text style={[styles.expTotal, { color: theme.text }]}>₹{expense.totalAmount}</Text>
              <Text style={[styles.expMeta, { color: theme.textSecondary }]}>
                Paid by {expense.paidByUserId === currentUser.id ? 'You' : (cohortMembers.find(m => m.userId === expense.paidByUserId)?.profile?.fullName || 'Member')} • {new Date(expense.createdAt).toLocaleDateString()}
              </Text>
            </View>

            {/* Split Breakdown */}
            <View style={[styles.detailsBox, { backgroundColor: theme.backgroundElement }]}>
              <Text style={[styles.detailsHeader, { color: theme.textSecondary }]}>
                SPLIT BREAKDOWN ({expense.splitType.toUpperCase()})
              </Text>

              <View style={styles.splitsBreakdownList}>
                {expense.splits.map((s) => {
                  const memberObj = cohortMembers.find((m) => m.userId === s.userId);
                  const name = s.userId === currentUser.id ? 'You' : memberObj?.profile?.fullName || s.userId;
                  const isPayer = s.userId === expense.paidByUserId;

                  return (
                    <View key={s.userId} style={styles.splitMemberRow}>
                      <View style={styles.memberNameRow}>
                        <View style={[styles.avatarMicro, { backgroundColor: '#6366F1' }]}>
                          <Text style={styles.avatarText}>{name.charAt(0).toUpperCase()}</Text>
                        </View>
                        <Text style={[styles.splitMemberName, { color: theme.text }]}>
                          {name}
                        </Text>
                        {isPayer && (
                          <View style={styles.payerBadge}>
                            <Text style={styles.payerBadgeText}>PAID</Text>
                          </View>
                        )}
                      </View>
                      <Text style={[styles.splitMemberAmt, { color: isPayer ? '#10B981' : theme.text }]}>
                        ₹{s.amount.toFixed(2)} {s.percentage ? `(${s.percentage}%)` : ''}
                      </Text>
                    </View>
                  );
                })}
              </View>

              {expense.notes && (
                <View style={styles.notesBox}>
                  <Text style={[styles.notesLabel, { color: theme.textSecondary }]}>NOTES</Text>
                  <Text style={[styles.expenseNotes, { color: theme.text }]}>{expense.notes}</Text>
                </View>
              )}
            </View>

            {/* Comments Section */}
            <View style={[styles.commentsSection, { backgroundColor: theme.backgroundElement }]}>
              <TransactionComments expenseId={expense.id} />
            </View>
          </ScrollView>
        </TouchableOpacity>
      </TouchableOpacity>

      {/* Edit Expense Modal */}
      {editModalVisible && (
        <EditExpenseModal
          visible={editModalVisible}
          onClose={() => setEditModalVisible(false)}
          expenseToEdit={expense}
        />
      )}
    </Modal>
  );
}

const styles = StyleSheet.create({
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalSheet: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    height: '90%', // Covers most of the page
    overflow: 'hidden',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    paddingTop: 20,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.1)',
  },
  closeBtn: {
    padding: 4,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '700',
  },
  scrollContent: {
    padding: 20,
    gap: 24,
  },
  topInfo: {
    alignItems: 'center',
    gap: 8,
    paddingBottom: 8,
  },
  expenseIcon: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: 'rgba(99, 102, 241, 0.1)',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 8,
  },
  expTitle: {
    fontSize: 22,
    fontWeight: '700',
    textAlign: 'center',
  },
  expTotal: {
    fontSize: 32,
    fontWeight: '800',
  },
  expMeta: {
    fontSize: 14,
    fontWeight: '500',
  },
  detailsBox: {
    padding: 20,
    borderRadius: 16,
    gap: 16,
  },
  detailsHeader: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1,
  },
  splitsBreakdownList: {
    gap: 12,
  },
  splitMemberRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  memberNameRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  avatarMicro: {
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#FFF',
    fontSize: 12,
    fontWeight: '700',
  },
  splitMemberName: {
    fontSize: 15,
    fontWeight: '600',
  },
  payerBadge: {
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  payerBadgeText: {
    color: '#10B981',
    fontSize: 10,
    fontWeight: '800',
  },
  splitMemberAmt: {
    fontSize: 16,
    fontWeight: '700',
  },
  notesBox: {
    marginTop: 8,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: 'rgba(150, 150, 150, 0.1)',
    gap: 6,
  },
  notesLabel: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  expenseNotes: {
    fontSize: 14,
    fontStyle: 'italic',
    lineHeight: 20,
  },
  commentsSection: {
    borderRadius: 16,
    padding: 20,
    minHeight: 200,
  },
});

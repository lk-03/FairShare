import React from 'react';
import { View, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { Expense, GroupMember, UserProfile } from '@/types';
import { Ionicons } from '@expo/vector-icons';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { TransactionComments } from '@/components/TransactionComments';
import { EditExpenseModal } from '@/components/EditExpenseModal';
import { Text } from '@/components/ui/Text';

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
  const [editModalVisible, setEditModalVisible] = React.useState(false);

  if (!expense) return null;

  const payerMember = cohortMembers.find(m => m.userId === expense.paidByUserId);
  const payerName = expense.paidByUserId === currentUser.id ? 'You' : (payerMember?.profile?.fullName || 'Member');

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <TouchableOpacity className="flex-1 bg-black/50 justify-end" activeOpacity={1} onPress={onClose}>
        <TouchableOpacity activeOpacity={1} className="bg-white rounded-t-3xl h-[88%] overflow-hidden border-t border-slate-200">
          {/* Header */}
          <View className="flex-row items-center justify-between px-5 py-4 border-b border-slate-100 bg-white">
            <TouchableOpacity className="p-1" onPress={onClose}>
              <Ionicons name="close" size={24} color="#0F172A" />
            </TouchableOpacity>
            <Text className="text-base font-bold text-slate-900">Payment Details</Text>
            <TouchableOpacity className="p-1.5 rounded-full bg-slate-50 border border-slate-200" onPress={() => setEditModalVisible(true)}>
              <Ionicons name="pencil" size={18} color="#0F172A" />
            </TouchableOpacity>
          </View>

          <ScrollView contentContainerClassName="p-5 gap-5" showsVerticalScrollIndicator={false}>
            {/* Top Info */}
            <View className="items-center gap-2 py-3 card-main">
              <View className="mb-2">
                <CategoryIcon category={expense.category} customIcon={expense.customIcon} size={64} variant="solid" />
              </View>
              <Text className="text-xl font-extrabold text-slate-900 text-center">{expense.title}</Text>
              <Text className="text-3xl font-extrabold text-slate-900">₹{expense.totalAmount}</Text>
              <Text className="text-xs font-semibold text-slate-500">
                Paid by {payerName} • {new Date(expense.createdAt).toLocaleDateString()}
              </Text>
            </View>

            {/* Split Breakdown */}
            <View className="card-main gap-4">
              <Text className="section-label">
                SPLIT BREAKDOWN ({expense.splitType.toUpperCase()})
              </Text>

              <View className="gap-3">
                {expense.splits.map((s) => {
                  const memberObj = cohortMembers.find((m) => m.userId === s.userId);
                  const name = s.userId === currentUser.id ? 'You' : memberObj?.profile?.fullName || s.userId;
                  const isPayer = s.userId === expense.paidByUserId;

                  return (
                    <View key={s.userId} className="flex-row justify-between items-center py-1">
                      <View className="flex-row items-center gap-2.5 flex-1 pr-2">
                        <View className="w-8 h-8 rounded-full bg-slate-100 items-center justify-center border border-slate-200">
                          <Text className="text-slate-700 text-xs font-bold">{name.charAt(0).toUpperCase()}</Text>
                        </View>
                        <Text className="text-sm font-bold text-slate-900" numberOfLines={1}>
                          {name}
                        </Text>
                        {isPayer && (
                          <View className="bg-emerald-50 px-2 py-0.5 rounded-md border border-emerald-100">
                            <Text className="text-[10px] font-bold text-emerald-600">PAID</Text>
                          </View>
                        )}
                      </View>
                      <Text className={`text-sm font-bold ${isPayer ? 'text-emerald-600' : 'text-slate-900'}`}>
                        ₹{s.amount.toFixed(2)} {s.percentage ? `(${s.percentage}%)` : ''}
                      </Text>
                    </View>
                  );
                })}
              </View>

              {expense.notes && (
                <View className="mt-2 pt-3 border-t border-slate-100 gap-1">
                  <Text className="section-label">NOTES</Text>
                  <Text className="text-sm text-slate-700 italic">{expense.notes}</Text>
                </View>
              )}
            </View>

            {/* Comments Section */}
            <View className="card-main p-5 min-h-[160px]">
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

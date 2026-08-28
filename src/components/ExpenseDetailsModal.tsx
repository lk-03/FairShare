import React, { useState } from 'react';
import { View, Modal, TouchableOpacity, ScrollView, Image, useColorScheme } from 'react-native';
import { Expense, ExpenseShortcut, GroupMember, UserProfile } from '@/types';
import { Ionicons } from '@expo/vector-icons';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { TransactionComments } from '@/components/TransactionComments';
import { EditExpenseModal } from '@/components/EditExpenseModal';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
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
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const { addShortcut } = useExpenseStore();

  const [editModalVisible, setEditModalVisible] = useState(false);

  if (!expense) return null;

  const payerMember = cohortMembers.find((m) => m.userId === expense.paidByUserId);
  const payerName =
    expense.paidByUserId === currentUser.id
      ? 'You'
      : payerMember?.profile?.fullName || 'Member';

  const handleSaveAsShortcut = () => {
    const newShortcut: ExpenseShortcut = {
      id: `sc_${Date.now()}`,
      cohortId: expense.cohortId,
      title: expense.title,
      category: expense.category,
      customIcon: expense.customIcon,
      amount: expense.totalAmount,
      paidByUserId: expense.paidByUserId,
      isMultiplePayers: false,
      splitType: expense.splitType,
      splits: expense.splits,
      includedMemberIds: expense.splits ? expense.splits.map((s) => s.userId) : undefined,
      exactSplits: expense.splitType === 'exact' && expense.splits
        ? Object.fromEntries(expense.splits.map((s) => [s.userId, String(s.amount)]))
        : undefined,
      percentageSplits: expense.splitType === 'percentage' && expense.splits
        ? Object.fromEntries(expense.splits.map((s) => [s.userId, String(s.percentage || 0)]))
        : undefined,
      createdAt: new Date().toISOString(),
    };
    addShortcut(newShortcut);
    showAlert('Shortcut Saved', `"${expense.title}" saved to group shortcuts!`);
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/50 justify-end`}>
        <TouchableOpacity
          className="flex-1"
          activeOpacity={1}
          onPress={onClose}
        />
        <View className="bg-surface rounded-t-3xl h-[88%] overflow-hidden border-t border-surface">
          {/* Header */}
          <View className="flex-row items-center justify-between px-5 py-4 border-b border-surface bg-surface">
            <TouchableOpacity className="p-1" onPress={onClose}>
              <Ionicons name="close" size={24} color="#94A3B8" />
            </TouchableOpacity>
            <Text className="text-base font-bold text-main">Payment Details</Text>
            <View className="flex-row items-center gap-2">
              <TouchableOpacity
                className="p-2 rounded-full bg-accent-pill border border-surface"
                onPress={handleSaveAsShortcut}
                activeOpacity={0.7}
              >
                <Ionicons name="bookmark-outline" size={16} color="#38BDF8" />
              </TouchableOpacity>
              <TouchableOpacity
                className="p-2 rounded-full bg-accent-pill border border-surface"
                onPress={() => setEditModalVisible(true)}
                activeOpacity={0.7}
              >
                <Ionicons name="pencil" size={16} color="#94A3B8" />
              </TouchableOpacity>
            </View>
          </View>

          <ScrollView contentContainerClassName="p-5 gap-5" showsVerticalScrollIndicator={false}>
            {/* Top Info */}
            <View className="items-center gap-2 py-4 card-main">
              <View className="mb-2">
                <CategoryIcon
                  category={expense.category}
                  customIcon={expense.customIcon}
                  size={64}
                  variant="solid"
                />
              </View>
              <Text className="text-xl font-extrabold text-main text-center">
                {expense.title}
              </Text>
              <Text className="text-3xl font-extrabold text-main">₹{expense.totalAmount}</Text>
              <Text className="text-xs font-medium text-secondary">
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
                  const name =
                    memberObj?.profile?.nickname ||
                    memberObj?.profile?.fullName ||
                    (s.userId === currentUser.id ? 'You' : s.userId);
                  const username = memberObj?.profile?.username;
                  const hasVpa = !!memberObj?.profile?.vpaId;
                  const isPayer = s.userId === expense.paidByUserId;

                  return (
                    <View key={s.userId} className="flex-row justify-between items-center py-1.5">
                      <View className="flex-row items-center gap-2.5 flex-1 pr-2">
                        <View className="w-8 h-8 rounded-full bg-accent-pill items-center justify-center border border-surface overflow-hidden">
                          {memberObj?.profile?.avatarUrl ? (
                            <Image source={{ uri: memberObj.profile.avatarUrl }} className="w-8 h-8 rounded-full" />
                          ) : (
                            <Text className="text-main text-xs font-bold">
                              {name.charAt(0).toUpperCase()}
                            </Text>
                          )}
                        </View>
                        <View className="flex-1">
                          <View className="flex-row items-center gap-1.5 flex-wrap">
                            <Text className="text-sm font-bold text-main" numberOfLines={1}>
                              {s.userId === currentUser.id ? `${name} (You)` : name}
                            </Text>
                            {hasVpa && (
                              <Ionicons name="checkmark-circle" size={13} color="#38BDF8" />
                            )}
                            {isPayer && (
                              <View className="bg-emerald-500/10 px-2 py-0.5 rounded-md border border-emerald-500/20">
                                <Text className="text-[10px] font-bold text-emerald-500">PAID</Text>
                              </View>
                            )}
                          </View>
                          {username && (
                            <Text className="text-[11px] font-semibold text-cyan">
                              @{username}
                            </Text>
                          )}
                        </View>
                      </View>
                      <Text
                        className={`text-sm font-bold ${
                          isPayer ? 'text-emerald-500' : 'text-main'
                        }`}
                      >
                        ₹{s.amount.toFixed(2)} {s.percentage ? `(${s.percentage}%)` : ''}
                      </Text>
                    </View>
                  );
                })}
              </View>

              {expense.notes && (
                <View className="mt-2 pt-3 border-t border-surface gap-1">
                  <Text className="section-label">NOTES</Text>
                  <Text className="text-sm text-secondary italic">{expense.notes}</Text>
                </View>
              )}
            </View>

            {/* Comments Section */}
            <View className="card-main p-5 min-h-[160px]">
              <TransactionComments expenseId={expense.id} cohortId={expense.cohortId} />
            </View>
          </ScrollView>
        </View>
      </View>

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

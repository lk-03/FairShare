import React, { useState, useMemo } from 'react';
import { View, Modal, TouchableOpacity, ScrollView, Image, useColorScheme } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Expense, ExpenseShortcut, GroupMember, UserProfile } from '@/types';
import { Ionicons } from '@expo/vector-icons';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { TransactionComments } from '@/components/TransactionComments';
import { EditExpenseModal } from '@/components/EditExpenseModal';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
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
  const insets = useSafeAreaInsets();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { addShortcut } = useExpenseStore();
  const [editModalVisible, setEditModalVisible] = useState(false);

  const memberMap = useMemo(() => {
    const map = new Map<string, GroupMember>();
    cohortMembers.forEach((m) => map.set(m.userId, m));
    return map;
  }, [cohortMembers]);

  if (!expense) return null;

  const payerMember = memberMap.get(expense.paidByUserId);
  const payerName =
    expense.paidByUserId === currentUser.id
      ? 'You'
      : payerMember?.profile?.fullName || payerMember?.profile?.nickname || payerMember?.originalCsvName || 'Member';

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
    <Modal
      visible={visible}
      animationType="slide"
      statusBarTranslucent={true}
      onRequestClose={onClose}
    >
      <View
        className={`flex-1 ${activeThemeClass}`}
        style={{ backgroundColor: colors.surface }}
      >
        {/* Top Header */}
        <View
          className="px-5 pb-4 border-b flex-row items-center justify-between"
          style={{
            paddingTop: Math.max(insets.top + 8, 16),
            borderColor: colors.border,
            backgroundColor: colors.surface,
          }}
        >
          <TouchableOpacity
            onPress={onClose}
            className="flex-row items-center gap-1 py-1 px-2 -ml-2 rounded-full"
            activeOpacity={0.7}
          >
            <Ionicons name="chevron-back" size={22} color={colors.textSecondary} />
            <Text className="text-base font-bold" style={{ color: colors.textMain }}>
              Back
            </Text>
          </TouchableOpacity>

          <Text className="text-base font-extrabold" style={{ color: colors.textMain }}>
            Payment Details
          </Text>

          <View className="flex-row items-center gap-2">
            <TouchableOpacity
              className="p-2 rounded-full border"
              style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
              onPress={handleSaveAsShortcut}
              activeOpacity={0.7}
            >
              <Ionicons name="bookmark-outline" size={16} color={colors.cyan} />
            </TouchableOpacity>
            <TouchableOpacity
              className="p-2 rounded-full border"
              style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
              onPress={() => setEditModalVisible(true)}
              activeOpacity={0.7}
            >
              <Ionicons name="pencil" size={16} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>
        </View>

        <ScrollView
          contentContainerStyle={{
            padding: 20,
            gap: 20,
            paddingBottom: Math.max(insets.bottom + 28, 44),
          }}
          showsVerticalScrollIndicator={false}
        >
          {/* Top Info Card */}
          <View
            className="items-center gap-2 py-5 px-4 rounded-3xl border shadow-sm"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
              borderColor: colors.border,
            }}
          >
            <View className="mb-2">
              <CategoryIcon
                category={expense.category}
                customIcon={expense.customIcon}
                size={64}
                variant="solid"
              />
            </View>
            <Text className="text-xl font-extrabold text-center" style={{ color: colors.textMain }}>
              {expense.title}
            </Text>
            <Text className="text-3xl font-black" style={{ color: colors.textMain }}>
              {expense.currency || '₹'}{Number(expense.totalAmount || 0).toFixed(2)}
            </Text>
            <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
              Paid by {payerName} • {new Date(expense.createdAt || Date.now()).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
            </Text>
          </View>

          {/* Split Breakdown */}
          <View
            className="p-5 rounded-3xl gap-4 border shadow-sm"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center justify-between">
              <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                SPLIT BREAKDOWN ({(expense.splitType || 'equal').toUpperCase()})
              </Text>
              <View
                className="px-2 py-0.5 rounded-full"
                style={{ backgroundColor: `${colors.cyan}20` }}
              >
                <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
                  {(expense.splits || []).length} Members
                </Text>
              </View>
            </View>

            <View className="gap-3">
              {(expense.splits || []).map((s, idx) => {
                const memberObj = memberMap.get(s.userId);
                const isShadow = !!memberObj?.isPlaceholder;
                const isCurrentUser = s.userId === currentUser.id;
                const name =
                  (isCurrentUser
                    ? 'You'
                    : memberObj?.profile?.fullName ||
                      memberObj?.profile?.nickname ||
                      memberObj?.originalCsvName ||
                      s.userId ||
                      'Member') || 'Member';
                const username = memberObj?.profile?.username;
                const hasVpa = !!memberObj?.profile?.vpaId;
                const isPayer = s.userId === expense.paidByUserId;

                return (
                  <View key={`split_${s.userId || idx}_${idx}`} className="flex-row justify-between items-center py-1.5">
                    <View className="flex-row items-center gap-2.5 flex-1 pr-2">
                      <View
                        className="w-9 h-9 rounded-full items-center justify-center border overflow-hidden"
                        style={{ backgroundColor: colors.surface, borderColor: colors.border }}
                      >
                        {memberObj?.profile?.avatarUrl ? (
                          <Image source={{ uri: memberObj.profile.avatarUrl }} className="w-9 h-9 rounded-full" />
                        ) : (
                          <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                            {(name || 'M').charAt(0).toUpperCase()}
                          </Text>
                        )}
                      </View>
                      <View className="flex-1">
                        <View className="flex-row items-center gap-1.5 flex-wrap">
                          <Text className="text-sm font-bold" style={{ color: colors.textMain }} numberOfLines={1}>
                            {name}
                          </Text>
                          {hasVpa && (
                            <Ionicons name="checkmark-circle" size={13} color={colors.cyan} />
                          )}
                          {isShadow && (
                            <View className="bg-amber-500/10 px-1.5 py-0.5 rounded border border-amber-500/30">
                              <Text className="text-[9px] font-bold text-amber-500">SHADOW</Text>
                            </View>
                          )}
                          {isPayer && (
                            <View className="bg-emerald-500/10 px-2 py-0.5 rounded-md border border-emerald-500/20">
                              <Text className="text-[10px] font-bold text-emerald-500">PAID</Text>
                            </View>
                          )}
                        </View>
                        {username && (
                          <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                            @{username}
                          </Text>
                        )}
                      </View>
                    </View>
                    <Text
                      className="text-sm font-bold"
                      style={{ color: isPayer ? '#10B981' : colors.textMain }}
                    >
                      {expense.currency || '₹'}{Number(s.amount || 0).toFixed(2)} {s.percentage ? `(${s.percentage}%)` : ''}
                    </Text>
                  </View>
                );
              })}
            </View>

            {expense.notes ? (
              <View
                className="mt-2 pt-3 border-t gap-1"
                style={{ borderColor: colors.border }}
              >
                <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                  NOTES
                </Text>
                <Text className="text-xs font-medium italic" style={{ color: colors.textSecondary }}>
                  {expense.notes}
                </Text>
              </View>
            ) : null}
          </View>

          {/* Comments Section */}
          <View
            className="p-5 rounded-3xl border shadow-sm min-h-[160px]"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
              borderColor: colors.border,
            }}
          >
            <TransactionComments expenseId={expense.id} cohortId={expense.cohortId} />
          </View>
        </ScrollView>
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

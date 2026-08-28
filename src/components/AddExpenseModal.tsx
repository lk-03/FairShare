import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  Alert,
  StatusBar,
  useColorScheme,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { compressReceiptImage } from '@/utils/imageCompressor';
import { SplitType, ExpenseSplit, Expense } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface AddExpenseModalProps {
  visible: boolean;
  onClose: () => void;
  cohortId?: string;
}

type ExpenseSubView = 'main' | 'who_paid' | 'multiple_paid' | 'adjust_split';

export function AddExpenseModal({ visible, onClose, cohortId }: AddExpenseModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const colors = {
    screen: isDark ? '#0D131A' : '#F8FAFC',
    surface: isDark ? '#121A23' : '#FFFFFF',
    border: isDark ? '#243447' : '#E2E8F0',
    textMain: isDark ? '#FFFFFF' : '#0F172A',
    textSecondary: isDark ? '#7E95A8' : '#64748B',
    accentPill: isDark ? 'rgba(255, 255, 255, 0.10)' : 'rgba(0, 0, 0, 0.05)',
    cyan: '#38BDF8',
  };

  const { cohorts, members, currentUser, addExpense } = useExpenseStore();

  const [selectedCohortId, setSelectedCohortId] = useState(cohortId || cohorts[0]?.id || '');
  const activeCohort = cohorts.find((c) => c.id === selectedCohortId) || cohorts[0];
  const cohortMembers = members[activeCohort?.id] || [];

  // Active Sub-screen View
  const [currentView, setCurrentView] = useState<ExpenseSubView>('main');

  // Form Fields
  const [title, setTitle] = useState('');
  const [totalAmountStr, setTotalAmountStr] = useState('');
  const [category, setCategory] = useState('Dining');
  const [customCategoryName, setCustomCategoryName] = useState('');
  const [customIcon, setCustomIcon] = useState('cart');
  const [notes, setNotes] = useState('');
  const [receiptUri, setReceiptUri] = useState<string | null>(null);
  const [expenseDate, setExpenseDate] = useState(new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));

  // Auxiliary Sub-modals
  const [categoryModalVisible, setCategoryModalVisible] = useState(false);
  const [notesModalVisible, setNotesModalVisible] = useState(false);
  const [groupPickerVisible, setGroupPickerVisible] = useState(false);

  // Payer State
  const [isMultiplePayers, setIsMultiplePayers] = useState(false);
  const [paidByUserId, setPaidByUserId] = useState(currentUser.id);
  const [paidAmounts, setPaidAmounts] = useState<Record<string, string>>({});

  // Split State
  const [splitType, setSplitType] = useState<SplitType>('equal');
  const [includedMemberIds, setIncludedMemberIds] = useState<string[]>([]);
  const [exactSplits, setExactSplits] = useState<Record<string, string>>({});
  const [percentSplits, setPercentSplits] = useState<Record<string, string>>({});
  const [shareSplits, setShareSplits] = useState<Record<string, string>>({});
  const [adjustmentSplits, setAdjustmentSplits] = useState<Record<string, string>>({});

  const totalAmount = parseFloat(totalAmountStr) || 0;

  // Initialize and reset form when modal appears
  useEffect(() => {
    if (visible) {
      const initialCohortId = cohortId || cohorts[0]?.id || '';
      setSelectedCohortId(initialCohortId);
      const mList = members[initialCohortId] || [];
      setIncludedMemberIds(mList.map((m) => m.userId));
      setPaidByUserId(currentUser.id);
      setIsMultiplePayers(false);
      setPaidAmounts({});
      setTitle('');
      setTotalAmountStr('');
      setCategory('Dining');
      setCustomCategoryName('');
      setCustomIcon('cart');
      setNotes('');
      setReceiptUri(null);
      setSplitType('equal');
      setExactSplits({});
      setPercentSplits({});
      setShareSplits({});
      setAdjustmentSplits({});
      setCurrentView('main');
    }
  }, [visible, cohortId, cohorts, members, currentUser.id]);

  // Sync includedMemberIds when cohort changes
  useEffect(() => {
    if (cohortMembers.length > 0 && includedMemberIds.length === 0) {
      setIncludedMemberIds(cohortMembers.map((m) => m.userId));
    }
  }, [cohortMembers]);

  // Receipt Pickers
  const handlePickReceipt = async () => {
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        const compressed = await compressReceiptImage(result.assets[0].uri);
        setReceiptUri(compressed);
      }
    } catch (e) {
      console.warn('Image picker error:', e);
    }
  };

  const handleTakeReceiptPhoto = async () => {
    try {
      const { status } = await ImagePicker.requestCameraPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Camera access is required to take receipt photos.');
        return;
      }
      const result = await ImagePicker.launchCameraAsync({
        allowsEditing: true,
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]) {
        const compressed = await compressReceiptImage(result.assets[0].uri);
        setReceiptUri(compressed);
      }
    } catch (e) {
      console.warn('Camera error:', e);
    }
  };

  // Helper Labels
  const singlePayerName = useMemo(() => {
    if (isMultiplePayers) return 'multiple people';
    if (paidByUserId === currentUser.id) return 'you';
    const found = cohortMembers.find((m) => m.userId === paidByUserId);
    return found?.profile?.fullName || 'member';
  }, [isMultiplePayers, paidByUserId, currentUser.id, cohortMembers]);

  const splitLabel = useMemo(() => {
    if (splitType === 'equal') return 'equally';
    if (splitType === 'exact') return 'unequally';
    if (splitType === 'percentage') return 'by percentages';
    if (splitType === 'shares') return 'by shares';
    if (splitType === 'adjustment') return 'by adjustment';
    return 'equally';
  }, [splitType]);

  // Multiple Payer Validation Math
  const totalPaidByMembers = useMemo(() => {
    return Object.values(paidAmounts).reduce((acc, val) => acc + (parseFloat(val) || 0), 0);
  }, [paidAmounts]);

  const multiplePaidRemaining = Math.max(0, totalAmount - totalPaidByMembers);

  // Split Calculation Helpers
  const equalPerPerson = useMemo(() => {
    const count = includedMemberIds.length;
    if (count === 0 || totalAmount <= 0) return '0.00';
    return (totalAmount / count).toFixed(2);
  }, [includedMemberIds, totalAmount]);

  const allSelected = includedMemberIds.length === cohortMembers.length;

  const toggleSelectAll = () => {
    if (allSelected) {
      setIncludedMemberIds([]);
    } else {
      setIncludedMemberIds(cohortMembers.map((m) => m.userId));
    }
  };

  const toggleMemberInclusion = (uId: string) => {
    if (includedMemberIds.includes(uId)) {
      setIncludedMemberIds(includedMemberIds.filter((id) => id !== uId));
    } else {
      setIncludedMemberIds([...includedMemberIds, uId]);
    }
  };

  // Adjustment Calculation Helpers
  const totalAdjustments = useMemo(() => {
    return cohortMembers.reduce((sum, m) => {
      const adj = parseFloat(adjustmentSplits[m.userId] || '0') || 0;
      return sum + Math.max(0, adj);
    }, 0);
  }, [cohortMembers, adjustmentSplits]);

  const remainingForAdjustment = totalAmount - totalAdjustments;
  const baseAdjustmentShare = cohortMembers.length > 0 && remainingForAdjustment >= 0
    ? remainingForAdjustment / cohortMembers.length
    : 0;

  const getMemberAdjustmentFinalShare = (userId: string) => {
    const adj = parseFloat(adjustmentSplits[userId] || '0') || 0;
    if (remainingForAdjustment < 0) return adj;
    return baseAdjustmentShare + adj;
  };

  // Submit Handler
  const handleSave = async () => {
    if (!title.trim()) {
      Alert.alert('Missing Description', 'Please enter a description for this expense.');
      return;
    }

    if (totalAmount <= 0) {
      Alert.alert('Invalid Amount', 'Please enter an expense amount greater than 0.');
      return;
    }

    if (!activeCohort) {
      Alert.alert('No Group', 'Please select an event group for this expense.');
      return;
    }

    let calculatedSplits: ExpenseSplit[] = [];

    if (splitType === 'equal') {
      const activeIds = includedMemberIds.length > 0 ? includedMemberIds : cohortMembers.map((m) => m.userId);
      const count = activeIds.length;
      const baseShare = Math.floor((totalAmount / count) * 100) / 100;
      let remainder = Number((totalAmount - baseShare * count).toFixed(2));

      calculatedSplits = activeIds.map((uId, idx) => {
        const amt = idx === 0 ? Number((baseShare + remainder).toFixed(2)) : baseShare;
        return { userId: uId, amount: amt };
      });
    } else if (splitType === 'exact') {
      let sum = 0;
      calculatedSplits = cohortMembers.map((m) => {
        const amt = parseFloat(exactSplits[m.userId] || '0') || 0;
        sum += amt;
        return { userId: m.userId, amount: amt };
      });

      if (Math.abs(sum - totalAmount) > 0.05) {
        Alert.alert('Split Mismatch', `Exact split sum (₹${sum.toFixed(2)}) must equal total (₹${totalAmount.toFixed(2)}).`);
        return;
      }
    } else if (splitType === 'percentage') {
      let totalPct = 0;
      calculatedSplits = cohortMembers.map((m) => {
        const pct = parseFloat(percentSplits[m.userId] || '0') || 0;
        totalPct += pct;
        const amt = Number(((pct / 100) * totalAmount).toFixed(2));
        return { userId: m.userId, amount: amt, percentage: pct };
      });

      if (Math.abs(totalPct - 100) > 0.5) {
        Alert.alert('Percentage Mismatch', `Total percentages (${totalPct}%) must equal 100%.`);
        return;
      }
    } else if (splitType === 'shares') {
      let totalShares = 0;
      cohortMembers.forEach((m) => {
        totalShares += parseFloat(shareSplits[m.userId] || '1') || 1;
      });

      calculatedSplits = cohortMembers.map((m) => {
        const shares = parseFloat(shareSplits[m.userId] || '1') || 1;
        const amt = Number(((shares / totalShares) * totalAmount).toFixed(2));
        return { userId: m.userId, amount: amt };
      });
    } else if (splitType === 'adjustment') {
      if (totalAdjustments > totalAmount) {
        Alert.alert(
          'Adjustments Exceed Total',
          `Total adjustments (₹${totalAdjustments.toFixed(2)}) cannot exceed total expense (₹${totalAmount.toFixed(2)}).`
        );
        return;
      }

      const count = cohortMembers.length;
      const remaining = totalAmount - totalAdjustments;
      const baseShare = Math.floor((remaining / count) * 100) / 100;
      let remainder = Number((remaining - baseShare * count).toFixed(2));

      calculatedSplits = cohortMembers.map((m, idx) => {
        const adj = parseFloat(adjustmentSplits[m.userId] || '0') || 0;
        const base = idx === 0 ? Number((baseShare + remainder).toFixed(2)) : baseShare;
        const finalAmt = Number((base + adj).toFixed(2));
        return { userId: m.userId, amount: finalAmt };
      });
    }

    const finalPayerId = isMultiplePayers ? (paidByUserId || currentUser.id) : paidByUserId;

    const newExpense: Expense = {
      id: `exp_${Date.now()}`,
      cohortId: activeCohort.id,
      title: title.trim(),
      category: category === 'Custom' && customCategoryName.trim() ? customCategoryName.trim() : category,
      customIcon: category === 'Custom' ? customIcon : undefined,
      totalAmount,
      currency: activeCohort.currency || 'INR',
      paidByUserId: finalPayerId,
      splitType,
      splits: calculatedSplits,
      receiptUrl: receiptUri || undefined,
      notes: notes.trim() || undefined,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await addExpense(newExpense);
    onClose();
  };

  const categories = ['Dining', 'Transport', 'Accommodation', 'Utilities', 'Entertainment', 'Custom'];

  return (
    <Modal visible={visible} animationType="slide" transparent={false} onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass}`} style={{ backgroundColor: colors.screen }}>
        <SafeAreaView className="flex-1" edges={['top', 'bottom']}>
          <StatusBar barStyle={isDark ? 'light-content' : 'dark-content'} />

          {/* ====================================================================
              VIEW 1: MAIN EXPENSE ENTRY SCREEN
             ==================================================================== */}
          {currentView === 'main' && (
            <View className="flex-1 justify-between">
              <View>
                {/* Header */}
                <View
                  className="flex-row items-center justify-between px-4 py-3.5"
                  style={{ backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border }}
                >
                  <TouchableOpacity onPress={onClose} className="p-2 rounded-xl">
                    <Ionicons name="arrow-back" size={24} color={colors.textSecondary} />
                  </TouchableOpacity>
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Add expense
                  </Text>
                  <TouchableOpacity onPress={handleSave} className="p-2 rounded-xl">
                    <Ionicons name="checkmark" size={26} color={colors.cyan} />
                  </TouchableOpacity>
                </View>

                {/* Group Cohort Chip */}
                <View className="px-5 pt-4">
                  <TouchableOpacity
                    className="flex-row items-center gap-2 px-3.5 py-1.5 rounded-full self-start"
                    style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                    onPress={() => setGroupPickerVisible(true)}
                    activeOpacity={0.7}
                  >
                    <Text className="text-xs font-medium" style={{ color: colors.textSecondary }}>
                      With you and:
                    </Text>
                    <View className="flex-row items-center gap-1.5">
                      <GroupAvatar
                        avatarUrl={activeCohort?.avatarUrl || activeCohort?.bannerUrl}
                        category={activeCohort?.category}
                        customIcon={activeCohort?.customIcon}
                        size={20}
                        variant="solid"
                      />
                      <Text className="text-xs font-bold" style={{ color: colors.textMain }} numberOfLines={1}>
                        All of {activeCohort?.name || 'Group'}
                      </Text>
                      <Ionicons name="chevron-down" size={14} color={colors.textSecondary} />
                    </View>
                  </TouchableOpacity>
                </View>

                {/* Main Inputs Area */}
                <View className="px-5 pt-6 gap-5">
                  {/* Description Input with Category Button */}
                  <View className="flex-row items-center gap-3.5">
                    <TouchableOpacity
                      className="w-12 h-12 rounded-2xl items-center justify-center shadow-sm"
                      style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                      onPress={() => setCategoryModalVisible(true)}
                      activeOpacity={0.8}
                    >
                      <CategoryIcon category={category} customIcon={customIcon} size={26} variant="solid" />
                    </TouchableOpacity>
                    <TextInput
                      className="flex-1 text-base font-semibold py-2.5"
                      style={{
                        color: colors.textMain,
                        borderBottomWidth: 1.5,
                        borderBottomColor: colors.border,
                      }}
                      placeholder="Enter a description"
                      placeholderTextColor={colors.textSecondary}
                      value={title}
                      onChangeText={setTitle}
                      autoFocus
                    />
                  </View>

                  {/* Amount Input with Currency Symbol Box */}
                  <View className="flex-row items-center gap-3.5">
                    <View
                      className="w-12 h-12 rounded-2xl items-center justify-center shadow-sm"
                      style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                    >
                      <Text className="text-xl font-extrabold" style={{ color: colors.textMain }}>
                        ₹
                      </Text>
                    </View>
                    <TextInput
                      className="flex-1 text-3xl font-extrabold py-2"
                      style={{
                        color: colors.textMain,
                        borderBottomWidth: 1.5,
                        borderBottomColor: colors.border,
                      }}
                      placeholder="0.00"
                      placeholderTextColor={colors.textSecondary}
                      keyboardType="decimal-pad"
                      value={totalAmountStr}
                      onChangeText={setTotalAmountStr}
                    />
                  </View>

                  {/* Natural Language Sentence Payer & Split Controls */}
                  <View className="flex-row items-center justify-center flex-wrap gap-2 py-4 mt-2">
                    <Text className="text-sm font-medium" style={{ color: colors.textSecondary }}>
                      Paid by
                    </Text>
                    <TouchableOpacity
                      className="px-3.5 py-1.5 rounded-xl shadow-sm"
                      style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                      onPress={() => setCurrentView('who_paid')}
                      activeOpacity={0.8}
                    >
                      <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                        {singlePayerName}
                      </Text>
                    </TouchableOpacity>

                    <Text className="text-sm font-medium" style={{ color: colors.textSecondary }}>
                      and split
                    </Text>
                    <TouchableOpacity
                      className="px-3.5 py-1.5 rounded-xl shadow-sm"
                      style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                      onPress={() => setCurrentView('adjust_split')}
                      activeOpacity={0.8}
                    >
                      <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                        {splitLabel}
                      </Text>
                    </TouchableOpacity>
                  </View>

                  {/* Notes preview if entered */}
                  {notes ? (
                    <View
                      className="p-3 rounded-2xl flex-row items-center justify-between"
                      style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    >
                      <Text className="text-xs italic flex-1" style={{ color: colors.textSecondary }} numberOfLines={1}>
                        Note: {notes}
                      </Text>
                      <TouchableOpacity onPress={() => setNotes('')}>
                        <Ionicons name="close-circle" size={16} color={colors.textSecondary} />
                      </TouchableOpacity>
                    </View>
                  ) : null}

                  {/* Receipt preview if attached */}
                  {receiptUri ? (
                    <View
                      className="flex-row items-center gap-3 p-2.5 rounded-2xl"
                      style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    >
                      <Image source={{ uri: receiptUri }} className="w-12 h-12 rounded-xl" />
                      <View className="flex-1">
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                          Receipt attached
                        </Text>
                        <Text className="text-[10px]" style={{ color: colors.textSecondary }}>
                          Ready for ledger audit
                        </Text>
                      </View>
                      <TouchableOpacity onPress={() => setReceiptUri(null)}>
                        <Ionicons name="trash-outline" size={18} color="#F87171" />
                      </TouchableOpacity>
                    </View>
                  ) : null}
                </View>
              </View>

              {/* Bottom Accessories Toolbar */}
              <View
                className="flex-row items-center justify-between px-5 py-3.5"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                {/* Group Indicator */}
                <TouchableOpacity
                  className="flex-row items-center gap-2"
                  onPress={() => setGroupPickerVisible(true)}
                >
                  <Ionicons name="people" size={18} color={colors.cyan} />
                  <Text className="text-xs font-semibold max-w-[140px]" style={{ color: colors.textMain }} numberOfLines={1}>
                    {activeCohort?.name || 'Cohort'}
                  </Text>
                </TouchableOpacity>

                {/* Action Badges on Right */}
                <View className="flex-row items-center gap-3">
                  {/* Date Button */}
                  <View
                    className="px-2.5 py-1.5 rounded-xl flex-row items-center gap-1.5"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                  >
                    <Ionicons name="calendar-outline" size={14} color={colors.textSecondary} />
                    <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                      {expenseDate}
                    </Text>
                  </View>

                  {/* Camera / Receipt Button */}
                  <TouchableOpacity
                    className="w-9 h-9 rounded-xl items-center justify-center"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={() => {
                      Alert.alert('Attach Receipt', 'Choose a source for your receipt:', [
                        { text: 'Take Photo', onPress: handleTakeReceiptPhoto },
                        { text: 'Choose from Library', onPress: handlePickReceipt },
                        { text: 'Cancel', style: 'cancel' },
                      ]);
                    }}
                  >
                    <Ionicons name="camera" size={17} color={colors.cyan} />
                  </TouchableOpacity>

                  {/* Notes Button */}
                  <TouchableOpacity
                    className="w-9 h-9 rounded-xl items-center justify-center"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={() => setNotesModalVisible(true)}
                  >
                    <Ionicons name="document-text" size={17} color={notes ? colors.cyan : colors.textSecondary} />
                  </TouchableOpacity>
                </View>
              </View>
            </View>
          )}

          {/* ====================================================================
              VIEW 2: "WHO PAID?" SCREEN
             ==================================================================== */}
          {currentView === 'who_paid' && (
            <View className="flex-1 justify-between">
              <View className="flex-1">
                <View
                  className="flex-row items-center justify-between px-4 py-3.5"
                  style={{ backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border }}
                >
                  <TouchableOpacity onPress={() => setCurrentView('main')} className="p-2 rounded-xl">
                    <Ionicons name="arrow-back" size={24} color={colors.textSecondary} />
                  </TouchableOpacity>
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Who paid?
                  </Text>
                  <View className="w-8" />
                </View>

                <ScrollView className="flex-1 pt-2">
                  {cohortMembers.map((m) => {
                    const isSelected = !isMultiplePayers && paidByUserId === m.userId;
                    const name = m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');

                    return (
                      <TouchableOpacity
                        key={m.userId}
                        className="flex-row items-center justify-between px-5 py-3.5"
                        style={{ borderBottomWidth: 1, borderBottomColor: colors.border }}
                        activeOpacity={0.7}
                        onPress={() => {
                          setIsMultiplePayers(false);
                          setPaidByUserId(m.userId);
                          setCurrentView('main');
                        }}
                      >
                        <View className="flex-row items-center gap-3.5 flex-1">
                          <View
                            className="w-10 h-10 rounded-full items-center justify-center"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name.charAt(0).toUpperCase()}
                            </Text>
                          </View>
                          <Text className="text-base font-semibold" style={{ color: colors.textMain }}>
                            {m.userId === currentUser.id ? `${name} (You)` : name}
                          </Text>
                        </View>

                        {isSelected && <Ionicons name="checkmark" size={22} color={colors.cyan} />}
                      </TouchableOpacity>
                    );
                  })}

                  {/* Multiple People Option */}
                  <TouchableOpacity
                    className="flex-row items-center justify-between px-5 py-3.5 mt-2"
                    style={{ borderBottomWidth: 1, borderBottomColor: colors.border }}
                    activeOpacity={0.7}
                    onPress={() => {
                      setIsMultiplePayers(true);
                      setCurrentView('multiple_paid');
                    }}
                  >
                    <View className="flex-row items-center gap-3.5 flex-1">
                      <View
                        className="w-10 h-10 rounded-full items-center justify-center"
                        style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                      >
                        <Ionicons name="people" size={18} color={colors.cyan} />
                      </View>
                      <Text className="text-base font-semibold" style={{ color: colors.textMain }}>
                        Multiple people
                      </Text>
                    </View>
                    <Ionicons name="chevron-forward" size={20} color={colors.textSecondary} />
                  </TouchableOpacity>
                </ScrollView>
              </View>
            </View>
          )}

          {/* ====================================================================
              VIEW 3: "ENTER PAID AMOUNTS" (MULTIPLE PEOPLE) SCREEN
             ==================================================================== */}
          {currentView === 'multiple_paid' && (
            <View className="flex-1 justify-between">
              <View className="flex-1">
                <View
                  className="flex-row items-center justify-between px-4 py-3.5"
                  style={{ backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border }}
                >
                  <TouchableOpacity onPress={() => setCurrentView('who_paid')} className="p-2 rounded-xl">
                    <Ionicons name="arrow-back" size={24} color={colors.textSecondary} />
                  </TouchableOpacity>
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Enter paid amounts
                  </Text>
                  <TouchableOpacity
                    onPress={() => {
                      if (Math.abs(multiplePaidRemaining) > 0.05) {
                        Alert.alert('Amount Mismatch', `Paid total must match ₹${totalAmount.toFixed(2)}.`);
                        return;
                      }
                      setCurrentView('main');
                    }}
                    className="p-2 rounded-xl"
                  >
                    <Ionicons name="checkmark" size={26} color={colors.cyan} />
                  </TouchableOpacity>
                </View>

                <ScrollView className="flex-1 pt-2">
                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                    const val = paidAmounts[m.userId] || '';

                    return (
                      <View
                        key={m.userId}
                        className="flex-row items-center justify-between px-5 py-3.5"
                        style={{ borderBottomWidth: 1, borderBottomColor: colors.border }}
                      >
                        <View className="flex-row items-center gap-3.5 flex-1">
                          <View
                            className="w-10 h-10 rounded-full items-center justify-center"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name.charAt(0).toUpperCase()}
                            </Text>
                          </View>
                          <Text className="text-base font-semibold" style={{ color: colors.textMain }}>
                            {m.userId === currentUser.id ? `${name} (You)` : name}
                          </Text>
                        </View>

                        <View className="flex-row items-center gap-2">
                          <Text className="text-base font-bold" style={{ color: colors.textSecondary }}>
                            ₹
                          </Text>
                          <TextInput
                            className="w-24 h-10 text-right text-base font-bold px-2"
                            style={{
                              color: colors.textMain,
                              borderBottomWidth: 1,
                              borderBottomColor: colors.border,
                            }}
                            placeholder="0.00"
                            placeholderTextColor={colors.textSecondary}
                            keyboardType="decimal-pad"
                            value={val}
                            onChangeText={(text) => setPaidAmounts({ ...paidAmounts, [m.userId]: text })}
                          />
                        </View>
                      </View>
                    );
                  })}
                </ScrollView>
              </View>

              {/* Bottom Balance Summary */}
              <View
                className="flex-col gap-1 items-center px-5 py-4"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                  ₹{totalPaidByMembers.toFixed(2)} of ₹{totalAmount.toFixed(2)}
                </Text>
                <Text
                  className={`text-xs font-semibold ${
                    multiplePaidRemaining === 0 ? 'text-emerald-400' : 'text-negative'
                  }`}
                >
                  {multiplePaidRemaining === 0 ? 'Fully allocated' : `₹${multiplePaidRemaining.toFixed(2)} left`}
                </Text>
              </View>
            </View>
          )}

          {/* ====================================================================
              VIEW 4: "ADJUST SPLIT" SCREEN (5 TABS INCLUDING ADJUSTMENT)
             ==================================================================== */}
          {currentView === 'adjust_split' && (
            <View className="flex-1 justify-between">
              <View className="flex-1">
                {/* Header */}
                <View
                  className="flex-row items-center justify-between px-4 py-3.5"
                  style={{ backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border }}
                >
                  <TouchableOpacity onPress={() => setCurrentView('main')} className="p-2 rounded-xl">
                    <Ionicons name="arrow-back" size={24} color={colors.textSecondary} />
                  </TouchableOpacity>
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Adjust split
                  </Text>
                  <TouchableOpacity onPress={() => setCurrentView('main')} className="p-2 rounded-xl">
                    <Ionicons name="checkmark" size={26} color={colors.cyan} />
                  </TouchableOpacity>
                </View>

                {/* Split Tabs Navigation (Scrollable 5 Tabs) */}
                <View style={{ backgroundColor: colors.surface, borderBottomWidth: 1, borderBottomColor: colors.border }}>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} className="flex-row">
                    <TouchableOpacity
                      className="px-4 py-3.5 items-center"
                      style={{ borderBottomWidth: 2, borderBottomColor: splitType === 'equal' ? colors.cyan : 'transparent' }}
                      onPress={() => setSplitType('equal')}
                    >
                      <Text className="text-xs font-bold" style={{ color: splitType === 'equal' ? colors.textMain : colors.textSecondary }}>
                        Equally
                      </Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                      className="px-4 py-3.5 items-center"
                      style={{ borderBottomWidth: 2, borderBottomColor: splitType === 'exact' ? colors.cyan : 'transparent' }}
                      onPress={() => setSplitType('exact')}
                    >
                      <Text className="text-xs font-bold" style={{ color: splitType === 'exact' ? colors.textMain : colors.textSecondary }}>
                        Unequally
                      </Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                      className="px-4 py-3.5 items-center"
                      style={{ borderBottomWidth: 2, borderBottomColor: splitType === 'percentage' ? colors.cyan : 'transparent' }}
                      onPress={() => setSplitType('percentage')}
                    >
                      <Text className="text-xs font-bold" style={{ color: splitType === 'percentage' ? colors.textMain : colors.textSecondary }}>
                        By %
                      </Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                      className="px-4 py-3.5 items-center"
                      style={{ borderBottomWidth: 2, borderBottomColor: splitType === 'shares' ? colors.cyan : 'transparent' }}
                      onPress={() => setSplitType('shares')}
                    >
                      <Text className="text-xs font-bold" style={{ color: splitType === 'shares' ? colors.textMain : colors.textSecondary }}>
                        By shares
                      </Text>
                    </TouchableOpacity>

                    <TouchableOpacity
                      className="px-4 py-3.5 items-center"
                      style={{ borderBottomWidth: 2, borderBottomColor: splitType === 'adjustment' ? colors.cyan : 'transparent' }}
                      onPress={() => setSplitType('adjustment')}
                    >
                      <Text className="text-xs font-bold" style={{ color: splitType === 'adjustment' ? colors.textMain : colors.textSecondary }}>
                        By adjustment
                      </Text>
                    </TouchableOpacity>
                  </ScrollView>
                </View>

                {/* Header Explainer */}
                <View
                  className="px-5 py-3"
                  style={{ backgroundColor: colors.accentPill, borderBottomWidth: 1, borderBottomColor: colors.border }}
                >
                  {splitType === 'equal' && (
                    <Text className="text-xs font-semibold" style={{ color: colors.textMain }}>
                      Select which people owe an equal share.
                    </Text>
                  )}
                  {splitType === 'exact' && (
                    <Text className="text-xs font-semibold" style={{ color: colors.textMain }}>
                      Specify exact currency amount for each person.
                    </Text>
                  )}
                  {splitType === 'percentage' && (
                    <Text className="text-xs font-semibold" style={{ color: colors.textMain }}>
                      Enter percentage share for each person.
                    </Text>
                  )}
                  {splitType === 'shares' && (
                    <Text className="text-xs font-semibold" style={{ color: colors.textMain }}>
                      Assign weighted shares (e.g. 1 share, 2 shares).
                    </Text>
                  )}
                  {splitType === 'adjustment' && (
                    <View className="items-center py-1 gap-1">
                      <Text className="text-sm font-bold text-center" style={{ color: colors.textMain }}>
                        Split by adjustment
                      </Text>
                      <Text className="text-xs text-center" style={{ color: colors.textSecondary }}>
                        Enter adjustments to reflect who owes extra; FairShare will distribute the remainder equally.
                      </Text>
                    </View>
                  )}
                </View>

                {/* Member Split Rows */}
                <ScrollView className="flex-1 pt-1">
                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                    const isIncluded = includedMemberIds.includes(m.userId);

                    return (
                      <View
                        key={m.userId}
                        className="flex-row items-center justify-between px-5 py-3.5"
                        style={{ borderBottomWidth: 1, borderBottomColor: colors.border }}
                      >
                        <TouchableOpacity
                          className="flex-row items-center gap-3.5 flex-1"
                          activeOpacity={0.7}
                          onPress={() => splitType === 'equal' && toggleMemberInclusion(m.userId)}
                        >
                          <View
                            className="w-10 h-10 rounded-full items-center justify-center"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name.charAt(0).toUpperCase()}
                            </Text>
                          </View>
                          <View className="flex-1">
                            <Text className="text-base font-semibold" style={{ color: colors.textMain }}>
                              {m.userId === currentUser.id ? `${name} (You)` : name}
                            </Text>
                            {splitType === 'adjustment' && (
                              <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                                ₹{getMemberAdjustmentFinalShare(m.userId).toFixed(2)}
                              </Text>
                            )}
                          </View>
                        </TouchableOpacity>

                        {/* Equal: Checkbox */}
                        {splitType === 'equal' && (
                          <TouchableOpacity
                            onPress={() => toggleMemberInclusion(m.userId)}
                            className="w-6 h-6 rounded-md items-center justify-center"
                            style={{
                              backgroundColor: isIncluded ? colors.cyan : colors.surface,
                              borderWidth: 1,
                              borderColor: isIncluded ? colors.cyan : colors.border,
                            }}
                          >
                            {isIncluded && <Ionicons name="checkmark" size={16} color="#0F172A" />}
                          </TouchableOpacity>
                        )}

                        {/* Unequal/Exact: Input */}
                        {splitType === 'exact' && (
                          <View className="flex-row items-center gap-2">
                            <Text className="text-base font-bold" style={{ color: colors.textSecondary }}>
                              ₹
                            </Text>
                            <TextInput
                              className="w-24 h-10 text-right text-base font-bold px-2"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1,
                                borderBottomColor: colors.border,
                              }}
                              placeholder="0.00"
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={exactSplits[m.userId] || ''}
                              onChangeText={(text) => setExactSplits({ ...exactSplits, [m.userId]: text })}
                            />
                          </View>
                        )}

                        {/* Percentage: Input */}
                        {splitType === 'percentage' && (
                          <View className="flex-row items-center gap-2">
                            <TextInput
                              className="w-16 h-10 text-right text-base font-bold px-2"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1,
                                borderBottomColor: colors.border,
                              }}
                              placeholder="0.0"
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={percentSplits[m.userId] || ''}
                              onChangeText={(text) => setPercentSplits({ ...percentSplits, [m.userId]: text })}
                            />
                            <Text className="text-base font-bold" style={{ color: colors.textSecondary }}>
                              %
                            </Text>
                          </View>
                        )}

                        {/* Shares: Stepper/Input */}
                        {splitType === 'shares' && (
                          <View className="flex-row items-center gap-2">
                            <TextInput
                              className="w-16 h-10 text-right text-base font-bold px-2"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1,
                                borderBottomColor: colors.border,
                              }}
                              placeholder="1"
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="number-pad"
                              value={shareSplits[m.userId] || '1'}
                              onChangeText={(text) => setShareSplits({ ...shareSplits, [m.userId]: text })}
                            />
                            <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                              shares
                            </Text>
                          </View>
                        )}

                        {/* Adjustment: Extra Amount Input */}
                        {splitType === 'adjustment' && (
                          <View className="flex-row items-center gap-2">
                            <Text className="text-base font-bold" style={{ color: colors.textSecondary }}>
                              +
                            </Text>
                            <TextInput
                              className="w-20 h-10 text-right text-base font-bold px-2"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1.5,
                                borderBottomColor: colors.cyan,
                              }}
                              placeholder="0.00"
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={adjustmentSplits[m.userId] || ''}
                              onChangeText={(text) => setAdjustmentSplits({ ...adjustmentSplits, [m.userId]: text })}
                            />
                          </View>
                        )}
                      </View>
                    );
                  })}
                </ScrollView>
              </View>

              {/* Bottom Summary Bar */}
              <View
                className="flex-row items-center justify-between px-5 py-4"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View>
                  {splitType === 'equal' && (
                    <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                      ~₹{equalPerPerson}/person{' '}
                      <Text className="text-xs font-normal" style={{ color: colors.textSecondary }}>
                        ({includedMemberIds.length} {includedMemberIds.length === 1 ? 'person' : 'people'})
                      </Text>
                    </Text>
                  )}
                  {splitType === 'exact' && (
                    <Text className="text-xs font-bold" style={{ color: colors.textSecondary }}>
                      Total: ₹{totalAmount.toFixed(2)}
                    </Text>
                  )}
                  {splitType === 'percentage' && (
                    <Text className="text-xs font-bold" style={{ color: colors.textSecondary }}>
                      Total: 100%
                    </Text>
                  )}
                  {splitType === 'shares' && (
                    <Text className="text-xs font-bold" style={{ color: colors.textSecondary }}>
                      Proportional weighted distribution
                    </Text>
                  )}
                  {splitType === 'adjustment' && (
                    <View>
                      <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                        {remainingForAdjustment >= 0
                          ? `Remainder: ₹${remainingForAdjustment.toFixed(2)} (~₹${baseAdjustmentShare.toFixed(2)}/person)`
                          : `Adjustments exceed total by ₹${Math.abs(remainingForAdjustment).toFixed(2)}`}
                      </Text>
                      <Text className="text-[10px] font-semibold" style={{ color: remainingForAdjustment >= 0 ? colors.cyan : '#F87171' }}>
                        Total expense: ₹{totalAmount.toFixed(2)}
                      </Text>
                    </View>
                  )}
                </View>

                {splitType === 'equal' && (
                  <TouchableOpacity
                    className="flex-row items-center gap-2 px-3 py-1.5 rounded-xl"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={toggleSelectAll}
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                      All
                    </Text>
                    <View
                      className="w-5 h-5 rounded-md items-center justify-center"
                      style={{
                        backgroundColor: allSelected ? colors.cyan : colors.surface,
                        borderWidth: 1,
                        borderColor: allSelected ? colors.cyan : colors.border,
                      }}
                    >
                      {allSelected && <Ionicons name="checkmark" size={14} color="#0F172A" />}
                    </View>
                  </TouchableOpacity>
                )}
              </View>
            </View>
          )}

          {/* ====================================================================
              AUXILIARY MODAL 1: CATEGORY ICON PICKER
             ==================================================================== */}
          <Modal visible={categoryModalVisible} transparent animationType="slide" onRequestClose={() => setCategoryModalVisible(false)}>
            <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
              <TouchableOpacity className="flex-1" activeOpacity={1} onPress={() => setCategoryModalVisible(false)} />
              <View
                className="rounded-t-3xl p-6 gap-4 max-h-[80%]"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View className="flex-row justify-between items-center">
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Select Category
                  </Text>
                  <TouchableOpacity onPress={() => setCategoryModalVisible(false)}>
                    <Ionicons name="close" size={22} color={colors.textSecondary} />
                  </TouchableOpacity>
                </View>

                <ScrollView className="gap-2" showsVerticalScrollIndicator={false}>
                  <View className="flex-row flex-wrap gap-2.5">
                    {categories.map((cat) => {
                      const isSelected = category === cat;
                      return (
                        <TouchableOpacity
                          key={cat}
                          className="flex-row items-center gap-2.5 px-4 py-3 rounded-2xl"
                          style={{
                            backgroundColor: isSelected ? colors.cyan : colors.accentPill,
                            borderWidth: 1,
                            borderColor: isSelected ? colors.cyan : colors.border,
                          }}
                          onPress={() => {
                            setCategory(cat);
                            if (cat !== 'Custom') setCategoryModalVisible(false);
                          }}
                        >
                          <CategoryIcon category={cat} customIcon={customIcon} size={24} variant="solid" />
                          <Text className="text-xs font-bold" style={{ color: isSelected ? '#0F172A' : colors.textMain }}>
                            {cat}
                          </Text>
                        </TouchableOpacity>
                      );
                    })}
                  </View>

                  {category === 'Custom' && (
                    <View className="gap-3 mt-4 pt-4" style={{ borderTopWidth: 1, borderTopColor: colors.border }}>
                      <Text className="section-label">CUSTOM CATEGORY NAME</Text>
                      <TextInput
                        className="h-12 rounded-2xl px-4 text-sm"
                        style={{
                          backgroundColor: colors.accentPill,
                          borderWidth: 1,
                          borderColor: colors.border,
                          color: colors.textMain,
                        }}
                        placeholder="e.g. Pet Supplies, Tickets..."
                        placeholderTextColor={colors.textSecondary}
                        value={customCategoryName}
                        onChangeText={setCustomCategoryName}
                      />

                      <Text className="section-label mt-2">CHOOSE CUSTOM ICON</Text>
                      <View className="flex-row flex-wrap gap-3">
                        {GENERIC_CUSTOM_ICONS.map((iconObj) => (
                          <TouchableOpacity
                            key={iconObj.name}
                            className="w-12 h-12 rounded-2xl items-center justify-center"
                            style={{
                              backgroundColor: customIcon === iconObj.name ? colors.cyan : colors.accentPill,
                              borderWidth: 1,
                              borderColor: customIcon === iconObj.name ? colors.cyan : colors.border,
                            }}
                            onPress={() => {
                              setCustomIcon(iconObj.name);
                              setCategoryModalVisible(false);
                            }}
                          >
                            <Ionicons
                              name={iconObj.name as any}
                              size={20}
                              color={customIcon === iconObj.name ? '#0F172A' : colors.cyan}
                            />
                          </TouchableOpacity>
                        ))}
                      </View>
                    </View>
                  )}
                </ScrollView>
              </View>
            </View>
          </Modal>

          {/* ====================================================================
              AUXILIARY MODAL 2: NOTES INPUT
             ==================================================================== */}
          <Modal visible={notesModalVisible} transparent animationType="slide" onRequestClose={() => setNotesModalVisible(false)}>
            <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
              <TouchableOpacity className="flex-1" activeOpacity={1} onPress={() => setNotesModalVisible(false)} />
              <View
                className="rounded-t-3xl p-6 gap-4"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View className="flex-row justify-between items-center">
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Expense Notes
                  </Text>
                  <TouchableOpacity onPress={() => setNotesModalVisible(false)}>
                    <Ionicons name="close" size={22} color={colors.textSecondary} />
                  </TouchableOpacity>
                </View>

                <TextInput
                  className="h-28 rounded-2xl p-4 text-sm text-top"
                  style={{
                    backgroundColor: colors.accentPill,
                    borderWidth: 1,
                    borderColor: colors.border,
                    color: colors.textMain,
                  }}
                  placeholder="Add additional details, receipt notes, or tax memos..."
                  placeholderTextColor={colors.textSecondary}
                  multiline
                  value={notes}
                  onChangeText={setNotes}
                />

                <TouchableOpacity
                  className="py-3.5 rounded-2xl items-center shadow-sm"
                  style={{ backgroundColor: colors.cyan }}
                  onPress={() => setNotesModalVisible(false)}
                >
                  <Text className="font-bold text-sm" style={{ color: '#0F172A' }}>
                    Save Note
                  </Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>

          {/* ====================================================================
              AUXILIARY MODAL 3: GROUP COHORT SELECTOR
             ==================================================================== */}
          <Modal visible={groupPickerVisible} transparent animationType="slide" onRequestClose={() => setGroupPickerVisible(false)}>
            <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
              <TouchableOpacity className="flex-1" activeOpacity={1} onPress={() => setGroupPickerVisible(false)} />
              <View
                className="rounded-t-3xl p-6 gap-4 border-t border-surface"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View className="flex-row justify-between items-center">
                  <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                    Select Group
                  </Text>
                  <TouchableOpacity onPress={() => setGroupPickerVisible(false)}>
                    <Ionicons name="close" size={22} color={colors.textSecondary} />
                  </TouchableOpacity>
                </View>

                <ScrollView className="gap-2" showsVerticalScrollIndicator={false}>
                  {cohorts.map((c) => (
                    <TouchableOpacity
                      key={c.id}
                      className="flex-row items-center gap-3.5 p-3.5 rounded-2xl"
                      style={{
                        backgroundColor: c.id === selectedCohortId ? colors.cyan : colors.accentPill,
                        borderWidth: 1,
                        borderColor: c.id === selectedCohortId ? colors.cyan : colors.border,
                      }}
                      onPress={() => {
                        setSelectedCohortId(c.id);
                        const mList = members[c.id] || [];
                        setIncludedMemberIds(mList.map((m) => m.userId));
                        setGroupPickerVisible(false);
                      }}
                    >
                      <GroupAvatar
                        avatarUrl={c.avatarUrl || c.bannerUrl}
                        category={c.category}
                        customIcon={c.customIcon}
                        size={36}
                        variant="solid"
                      />
                      <View className="flex-1">
                        <Text
                          className="text-base font-bold"
                          style={{ color: c.id === selectedCohortId ? '#0F172A' : colors.textMain }}
                        >
                          {c.name}
                        </Text>
                        {c.description ? (
                          <Text
                            className="text-xs"
                            style={{ color: c.id === selectedCohortId ? '#334155' : colors.textSecondary }}
                            numberOfLines={1}
                          >
                            {c.description}
                          </Text>
                        ) : null}
                      </View>
                    </TouchableOpacity>
                  ))}
                </ScrollView>
              </View>
            </View>
          </Modal>
        </SafeAreaView>
      </View>
    </Modal>
  );
}

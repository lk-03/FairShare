import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  StatusBar,
  useColorScheme,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { compressReceiptImage } from '@/utils/imageCompressor';
import { SplitType, ExpenseSplit, Expense } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface EditExpenseModalProps {
  visible: boolean;
  onClose: () => void;
  expenseToEdit?: Expense | null;
}

type ExpenseSubView = 'main' | 'who_paid' | 'multiple_paid' | 'adjust_split';

export function EditExpenseModal({ visible, onClose, expenseToEdit }: EditExpenseModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { cohorts, members, currentUser, updateExpense } = useExpenseStore();

  const selectedCohortId = expenseToEdit?.cohortId || cohorts[0]?.id || '';
  const currentCohort = cohorts.find((c) => c.id === selectedCohortId) || cohorts[0];
  const rawCohortMembers = members[selectedCohortId] || [];
  const cohortMembers = rawCohortMembers.filter(
    (m) =>
      !m.isPlaceholder ||
      expenseToEdit?.splits.some((s) => s.userId === m.userId) ||
      expenseToEdit?.paidByUserId === m.userId
  );

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
  const [expenseDate, setExpenseDate] = useState('Today');

  // Auxiliary Sub-modals
  const [categoryModalVisible, setCategoryModalVisible] = useState(false);
  const [notesModalVisible, setNotesModalVisible] = useState(false);

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
  const categories = ['Dining', 'Transport', 'Accommodation', 'Utilities', 'Entertainment', 'Custom'];

  // Initialize and populate existing expense
  useEffect(() => {
    if (expenseToEdit && visible) {
      setTitle(expenseToEdit.title);
      setTotalAmountStr(String(expenseToEdit.totalAmount));

      const capCat = expenseToEdit.category.charAt(0).toUpperCase() + expenseToEdit.category.slice(1);
      if (categories.includes(capCat)) {
        setCategory(capCat);
      } else {
        setCategory('Custom');
        setCustomCategoryName(expenseToEdit.category);
        setCustomIcon(expenseToEdit.customIcon || 'cart');
      }

      setPaidByUserId(expenseToEdit.paidByUserId);
      setIsMultiplePayers(false);
      setSplitType(expenseToEdit.splitType);

      // Split distributions
      const exacts: Record<string, string> = {};
      const percents: Record<string, string> = {};
      const adjs: Record<string, string> = {};
      const includedIds: string[] = [];

      expenseToEdit.splits.forEach((s) => {
        includedIds.push(s.userId);
        if (expenseToEdit.splitType === 'exact') exacts[s.userId] = String(s.amount);
        if (expenseToEdit.splitType === 'percentage' && s.percentage) percents[s.userId] = String(s.percentage);
      });

      setIncludedMemberIds(includedIds.length > 0 ? includedIds : cohortMembers.map((m) => m.userId));
      setExactSplits(exacts);
      setPercentSplits(percents);
      setShareSplits({});
      setAdjustmentSplits(adjs);
      setReceiptUri(expenseToEdit.receiptUrl || null);
      setNotes(expenseToEdit.notes || '');

      if (expenseToEdit.createdAt) {
        setExpenseDate(new Date(expenseToEdit.createdAt).toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));
      }

      setCurrentView('main');
    }
  }, [expenseToEdit, visible]);

  // Image Pickers
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
        showAlert('Permission Denied', 'Camera access is required to take receipt photos.');
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

  // 1. Multiple Payer Dynamic Remaining Math & Auto-Balance
  const { enteredPaidSum, unsetPaidMembers, placeholderPaidPerPerson, paidDiff } = useMemo(() => {
    let sum = 0;
    const unset: string[] = [];

    cohortMembers.forEach((m) => {
      const val = paidAmounts[m.userId];
      if (val !== undefined && val.trim() !== '') {
        sum += parseFloat(val) || 0;
      } else {
        unset.push(m.userId);
      }
    });

    const diff = totalAmount - sum;
    const rem = Math.max(0, diff);
    const placeholder = unset.length > 0 ? (rem / unset.length).toFixed(2) : '0.00';

    return {
      enteredPaidSum: sum,
      unsetPaidMembers: unset,
      placeholderPaidPerPerson: placeholder,
      paidDiff: diff,
    };
  }, [cohortMembers, paidAmounts, totalAmount]);

  const getMemberPaidAmount = (userId: string) => {
    const val = paidAmounts[userId];
    if (val !== undefined && val.trim() !== '') {
      return parseFloat(val) || 0;
    }
    return parseFloat(placeholderPaidPerPerson) || 0;
  };

  const autoBalancePaidAmounts = () => {
    if (paidDiff <= 0) return;
    const targets = unsetPaidMembers.length > 0 ? unsetPaidMembers : cohortMembers.map((m) => m.userId);
    const count = targets.length;
    const baseShare = Math.floor((paidDiff / count) * 100) / 100;
    const remainder = Number((paidDiff - baseShare * count).toFixed(2));

    const updated = { ...paidAmounts };
    targets.forEach((uId, idx) => {
      const current = parseFloat(updated[uId] || '0') || 0;
      const add = idx === 0 ? baseShare + remainder : baseShare;
      updated[uId] = (current + add).toFixed(2);
    });
    setPaidAmounts(updated);
  };

  // 2. Equal Split Calculation Helpers
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

  // 3. Exact / Unequal Split Dynamic Remaining Math & Auto-Balance
  const { enteredExactSum, unsetExactMembers, placeholderExactPerPerson, exactDiff } = useMemo(() => {
    let sum = 0;
    const unset: string[] = [];

    cohortMembers.forEach((m) => {
      const val = exactSplits[m.userId];
      if (val !== undefined && val.trim() !== '') {
        sum += parseFloat(val) || 0;
      } else {
        unset.push(m.userId);
      }
    });

    const diff = totalAmount - sum;
    const rem = Math.max(0, diff);
    const placeholder = unset.length > 0 ? (rem / unset.length).toFixed(2) : '0.00';

    return {
      enteredExactSum: sum,
      unsetExactMembers: unset,
      placeholderExactPerPerson: placeholder,
      exactDiff: diff,
    };
  }, [cohortMembers, exactSplits, totalAmount]);

  const getMemberExactAmount = (userId: string) => {
    const val = exactSplits[userId];
    if (val !== undefined && val.trim() !== '') {
      return parseFloat(val) || 0;
    }
    return parseFloat(placeholderExactPerPerson) || 0;
  };

  const autoBalanceExactSplits = () => {
    if (exactDiff <= 0) return;
    const targets = unsetExactMembers.length > 0 ? unsetExactMembers : cohortMembers.map((m) => m.userId);
    const count = targets.length;
    const baseShare = Math.floor((exactDiff / count) * 100) / 100;
    const remainder = Number((exactDiff - baseShare * count).toFixed(2));

    const updated = { ...exactSplits };
    targets.forEach((uId, idx) => {
      const current = parseFloat(updated[uId] || '0') || 0;
      const add = idx === 0 ? baseShare + remainder : baseShare;
      updated[uId] = (current + add).toFixed(2);
    });
    setExactSplits(updated);
  };

  // 4. Percentage Split Dynamic Remaining Math & Auto-Balance
  const { enteredPercentSum, unsetPercentMembers, placeholderPercentPerPerson, percentDiff } = useMemo(() => {
    let sum = 0;
    const unset: string[] = [];

    cohortMembers.forEach((m) => {
      const val = percentSplits[m.userId];
      if (val !== undefined && val.trim() !== '') {
        sum += parseFloat(val) || 0;
      } else {
        unset.push(m.userId);
      }
    });

    const diff = 100 - sum;
    const rem = Math.max(0, diff);
    const placeholder = unset.length > 0 ? (rem / unset.length).toFixed(1) : '0.0';

    return {
      enteredPercentSum: sum,
      unsetPercentMembers: unset,
      placeholderPercentPerPerson: placeholder,
      percentDiff: diff,
    };
  }, [cohortMembers, percentSplits]);

  const getMemberPercent = (userId: string) => {
    const val = percentSplits[userId];
    if (val !== undefined && val.trim() !== '') {
      return parseFloat(val) || 0;
    }
    return parseFloat(placeholderPercentPerPerson) || 0;
  };

  const autoBalancePercentSplits = () => {
    if (percentDiff <= 0) return;
    const targets = unsetPercentMembers.length > 0 ? unsetPercentMembers : cohortMembers.map((m) => m.userId);
    const count = targets.length;
    const share = Number((percentDiff / count).toFixed(1));

    const updated = { ...percentSplits };
    targets.forEach((uId) => {
      const current = parseFloat(updated[uId] || '0') || 0;
      updated[uId] = (current + share).toFixed(1);
    });
    setPercentSplits(updated);
  };

  // 5. Shares Dynamic Calculation Math with 0-share Auto-Exclusion
  const getMemberSharesCount = (userId: string) => {
    const raw = shareSplits[userId];
    if (raw === undefined) return 1;
    const parsed = parseInt(raw, 10);
    return isNaN(parsed) ? 0 : Math.max(0, parsed);
  };

  const totalSharesCount = useMemo(() => {
    return cohortMembers.reduce((sum, m) => {
      return sum + getMemberSharesCount(m.userId);
    }, 0);
  }, [cohortMembers, shareSplits]);

  const getMemberShareAmount = (userId: string) => {
    const shares = getMemberSharesCount(userId);
    if (shares === 0 || totalSharesCount <= 0 || totalAmount <= 0) return 0;
    return (shares / totalSharesCount) * totalAmount;
  };

  const handleShareIncrement = (userId: string) => {
    const current = getMemberSharesCount(userId);
    setShareSplits({ ...shareSplits, [userId]: String(current + 1) });
  };

  const handleShareDecrement = (userId: string) => {
    const current = getMemberSharesCount(userId);
    if (current > 0) {
      setShareSplits({ ...shareSplits, [userId]: String(current - 1) });
    }
  };

  // 6. Adjustment Calculation Helpers
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

  // Validation Checks for Sub-screens
  const isSplitValid = useMemo(() => {
    if (splitType === 'equal') return includedMemberIds.length > 0;
    if (splitType === 'exact') return exactDiff >= -0.05;
    if (splitType === 'percentage') return percentDiff >= -0.5;
    if (splitType === 'shares') return totalSharesCount > 0;
    if (splitType === 'adjustment') return remainingForAdjustment >= 0;
    return true;
  }, [splitType, includedMemberIds, exactDiff, percentDiff, totalSharesCount, remainingForAdjustment]);

  const isMultiplePaidValid = useMemo(() => {
    return paidDiff >= -0.05 && (unsetPaidMembers.length > 0 || Math.abs(paidDiff) <= 0.05);
  }, [paidDiff, unsetPaidMembers]);

  // Submit Handler
  const handleUpdate = async () => {
    if (!expenseToEdit) return;

    if (!title.trim()) {
      showAlert('Missing Description', 'Please enter a description for this expense.');
      return;
    }

    if (totalAmount <= 0) {
      showAlert('Invalid Amount', 'Please enter an expense amount greater than 0.');
      return;
    }

    let calculatedSplits: ExpenseSplit[] = [];

    if (splitType === 'equal') {
      const activeIds = includedMemberIds.length > 0 ? includedMemberIds : cohortMembers.map((m) => m.userId);
      const count = activeIds.length;
      if (count === 0) {
        showAlert('No Members Selected', 'Please select at least one person to share the expense.');
        return;
      }
      const baseShare = Math.floor((totalAmount / count) * 100) / 100;
      let remainder = Number((totalAmount - baseShare * count).toFixed(2));

      calculatedSplits = activeIds.map((uId, idx) => {
        const amt = idx === 0 ? Number((baseShare + remainder).toFixed(2)) : baseShare;
        return { userId: uId, amount: amt };
      });
    } else if (splitType === 'exact') {
      let sum = 0;
      calculatedSplits = cohortMembers.map((m) => {
        const amt = getMemberExactAmount(m.userId);
        sum += amt;
        return { userId: m.userId, amount: Number(amt.toFixed(2)) };
      });

      if (Math.abs(sum - totalAmount) > 0.05) {
        const diff = sum - totalAmount;
        showAlert(
          'Split Mismatch',
          diff > 0
            ? `Exact split sum is over by ₹${diff.toFixed(2)}.`
            : `Exact split sum is under by ₹${Math.abs(diff).toFixed(2)}.`
        );
        return;
      }
    } else if (splitType === 'percentage') {
      let totalPct = 0;
      calculatedSplits = cohortMembers.map((m) => {
        const pct = getMemberPercent(m.userId);
        totalPct += pct;
        const amt = Number(((pct / 100) * totalAmount).toFixed(2));
        return { userId: m.userId, amount: amt, percentage: pct };
      });

      if (Math.abs(totalPct - 100) > 0.5) {
        const diff = totalPct - 100;
        showAlert(
          'Percentage Mismatch',
          diff > 0
            ? `Total percentage is over by ${diff.toFixed(1)}%. Must equal 100%.`
            : `Total percentage is under by ${Math.abs(diff).toFixed(1)}%. Must equal 100%.`
        );
        return;
      }
    } else if (splitType === 'shares') {
      if (totalSharesCount <= 0) {
        showAlert('No Shares Assigned', 'Please assign at least 1 share across participants.');
        return;
      }
      // Exclude members with 0 shares automatically
      calculatedSplits = cohortMembers
        .filter((m) => getMemberSharesCount(m.userId) > 0)
        .map((m) => {
          const amt = Number(getMemberShareAmount(m.userId).toFixed(2));
          return { userId: m.userId, amount: amt };
        });
    } else if (splitType === 'adjustment') {
      if (totalAdjustments > totalAmount) {
        showAlert(
          'Adjustments Exceed Total',
          `Total adjustments (₹${totalAdjustments.toFixed(2)}) exceed total expense (₹${totalAmount.toFixed(2)}).`
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

    const updatedExpense: Expense = {
      ...expenseToEdit,
      title: title.trim(),
      category: category === 'Custom' && customCategoryName.trim() ? customCategoryName.trim() : category,
      customIcon: category === 'Custom' ? customIcon : undefined,
      totalAmount,
      paidByUserId: finalPayerId,
      splitType,
      splits: calculatedSplits,
      receiptUrl: receiptUri || undefined,
      notes: notes.trim() || undefined,
      updatedAt: new Date().toISOString(),
    };

    await updateExpense(updatedExpense);
    onClose();
  };

  return (
    <Modal visible={visible} animationType="slide" transparent={false} onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass}`} style={{ backgroundColor: colors.screen }}>
        <SafeAreaView className="flex-1" edges={['top', 'bottom']}>
          <StatusBar barStyle={isDark ? 'light-content' : 'dark-content'} />

          {/* ====================================================================
              VIEW 1: MAIN EXPENSE EDIT SCREEN
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
                    Edit expense
                  </Text>
                  <TouchableOpacity onPress={handleUpdate} className="p-2 rounded-xl">
                    <Ionicons name="checkmark" size={26} color={colors.cyan} />
                  </TouchableOpacity>
                </View>

                {/* Group Cohort Chip */}
                <View className="px-5 pt-4">
                  <View
                    className="flex-row items-center gap-2 px-3.5 py-1.5 rounded-full self-start"
                    style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                  >
                    <Text className="text-xs font-medium" style={{ color: colors.textSecondary }}>
                      With you and:
                    </Text>
                    <View className="flex-row items-center gap-1.5">
                      <GroupAvatar
                        avatarUrl={currentCohort?.avatarUrl || currentCohort?.bannerUrl}
                        category={currentCohort?.category}
                        customIcon={currentCohort?.customIcon}
                        size={20}
                        variant="solid"
                      />
                      <Text className="text-xs font-bold" style={{ color: colors.textMain }} numberOfLines={1}>
                        All of {currentCohort?.name || 'Group'}
                      </Text>
                    </View>
                  </View>
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
                      className="flex-1 text-base font-semibold px-2"
                      style={{
                        color: colors.textMain,
                        borderBottomWidth: 1.5,
                        borderBottomColor: colors.border,
                        minHeight: 48,
                        height: 48,
                        textAlignVertical: 'center',
                      }}
                      placeholder="Enter a description"
                      placeholderTextColor={colors.textSecondary}
                      value={title}
                      onChangeText={setTitle}
                      multiline={false}
                      scrollEnabled={false}
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
                      className="flex-1 text-3xl font-extrabold px-2"
                      style={{
                        color: colors.textMain,
                        borderBottomWidth: 1.5,
                        borderBottomColor: colors.border,
                        minHeight: 52,
                        height: 52,
                        textAlignVertical: 'center',
                      }}
                      placeholder="0.00"
                      placeholderTextColor={colors.textSecondary}
                      keyboardType="decimal-pad"
                      value={totalAmountStr}
                      onChangeText={setTotalAmountStr}
                      multiline={false}
                      scrollEnabled={false}
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
                        <Ionicons name="trash-outline" size={18} color={colors.red} />
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
                <View className="flex-row items-center gap-2">
                  <Ionicons name="people" size={18} color={colors.cyan} />
                  <Text className="text-xs font-semibold max-w-[140px]" style={{ color: colors.textMain }} numberOfLines={1}>
                    {currentCohort?.name || 'Cohort'}
                  </Text>
                </View>

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
                      showAlert('Attach Receipt', 'Choose a source for your receipt:', [
                        { text: 'Take Photo', style: 'default', icon: 'camera-outline', onPress: handleTakeReceiptPhoto },
                        { text: 'Choose from Library', style: 'default', icon: 'images-outline', onPress: handlePickReceipt },
                        { text: 'Cancel', style: 'cancel', icon: 'close-outline' },
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

                <ScrollView
                  className="flex-1 pt-2"
                  keyboardShouldPersistTaps="handled"
                  keyboardDismissMode="none"
                  showsVerticalScrollIndicator={false}
                >
                  {cohortMembers.map((m) => {
                    const isSelected = !isMultiplePayers && paidByUserId === m.userId;
                    const name = m.profile?.nickname || m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                    const username = m.profile?.username;
                    const hasVpa = !!m.profile?.vpaId;

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
                            className="w-10 h-10 rounded-full items-center justify-center overflow-hidden"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            {m.profile?.avatarUrl ? (
                              <Image source={{ uri: m.profile.avatarUrl }} className="w-10 h-10 rounded-full" />
                            ) : (
                              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                                {name.charAt(0).toUpperCase()}
                              </Text>
                            )}
                          </View>
                          <View className="flex-1">
                            <View className="flex-row items-center gap-1.5">
                              <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                                {m.userId === currentUser.id ? `${name} (You)` : name}
                              </Text>
                              {hasVpa && <Ionicons name="checkmark-circle" size={14} color={colors.cyan} />}
                            </View>
                            {username ? (
                              <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                                @{username}
                              </Text>
                            ) : null}
                          </View>
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
                      if (!isMultiplePaidValid) {
                        const diff = enteredPaidSum - totalAmount;
                        showAlert(
                          'Paid Amount Mismatch',
                          diff > 0
                            ? `Paid total exceeds bill by ₹${diff.toFixed(2)}.`
                            : `Paid total is under by ₹${Math.abs(diff).toFixed(2)}.`
                        );
                        return;
                      }
                      setCurrentView('main');
                    }}
                    className="p-2 rounded-xl"
                  >
                    <Ionicons name="checkmark" size={26} color={isMultiplePaidValid ? colors.cyan : colors.textSecondary} />
                  </TouchableOpacity>
                </View>

                <ScrollView
                  className="flex-1 pt-2"
                  keyboardShouldPersistTaps="handled"
                  keyboardDismissMode="none"
                  showsVerticalScrollIndicator={false}
                >
                  {cohortMembers.map((m) => {
                    const name = m.profile?.nickname || m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                    const username = m.profile?.username;
                    const hasVpa = !!m.profile?.vpaId;
                    const val = paidAmounts[m.userId] || '';

                    return (
                      <View
                        key={m.userId}
                        className="flex-row items-center justify-between px-5 py-3.5"
                        style={{ borderBottomWidth: 1, borderBottomColor: colors.border }}
                      >
                        <View className="flex-row items-center gap-3.5 flex-1">
                          <View
                            className="w-10 h-10 rounded-full items-center justify-center overflow-hidden"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            {m.profile?.avatarUrl ? (
                              <Image source={{ uri: m.profile.avatarUrl }} className="w-10 h-10 rounded-full" />
                            ) : (
                              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                                {name.charAt(0).toUpperCase()}
                              </Text>
                            )}
                          </View>
                          <View className="flex-1">
                            <View className="flex-row items-center gap-1.5">
                              <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                                {m.userId === currentUser.id ? `${name} (You)` : name}
                              </Text>
                              {hasVpa && <Ionicons name="checkmark-circle" size={14} color={colors.cyan} />}
                            </View>
                            {username ? (
                              <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                                @{username}
                              </Text>
                            ) : null}
                            <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                              ₹{getMemberPaidAmount(m.userId).toFixed(2)}
                            </Text>
                          </View>
                        </View>

                        <View className="flex-row items-center gap-2">
                          <Text className="text-base font-bold" style={{ color: colors.textSecondary }}>
                            ₹
                          </Text>
                          <TextInput
                            key={`paid_${m.userId}`}
                            className="w-24 px-2 text-right text-base font-bold"
                            style={{
                              color: colors.textMain,
                              borderBottomWidth: 1.5,
                              borderBottomColor: colors.border,
                              minHeight: 48,
                              height: 48,
                              textAlignVertical: 'center',
                            }}
                            placeholder={placeholderPaidPerPerson}
                            placeholderTextColor={colors.textSecondary}
                            keyboardType="decimal-pad"
                            value={val}
                            onChangeText={(text) => setPaidAmounts({ ...paidAmounts, [m.userId]: text })}
                            multiline={false}
                            scrollEnabled={false}
                          />
                        </View>
                      </View>
                    );
                  })}
                </ScrollView>
              </View>

              {/* Bottom Balance Summary & Auto-balance Button */}
              <View
                className="px-5 py-4 gap-2"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View className="flex-row items-center justify-between">
                  <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                    ₹{enteredPaidSum.toFixed(2)} of ₹{totalAmount.toFixed(2)}
                  </Text>
                  <Text
                    className="text-xs font-bold"
                    style={{
                      color:
                        paidDiff === 0 || Math.abs(paidDiff) <= 0.05
                          ? colors.emerald
                          : paidDiff < 0
                          ? colors.red
                          : colors.amber,
                    }}
                  >
                    {paidDiff === 0 || Math.abs(paidDiff) <= 0.05
                      ? 'Balanced'
                      : paidDiff < 0
                      ? `Over by ₹${Math.abs(paidDiff).toFixed(2)}`
                      : `₹${paidDiff.toFixed(2)} remaining`}
                  </Text>
                </View>

                {paidDiff > 0.05 && (
                  <TouchableOpacity
                    className="py-2 px-3 rounded-xl items-center self-center"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={autoBalancePaidAmounts}
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                      Distribute remaining ₹{paidDiff.toFixed(2)} equally
                    </Text>
                  </TouchableOpacity>
                )}
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
                  <TouchableOpacity
                    onPress={() => {
                      if (!isSplitValid) {
                        if (splitType === 'exact' && exactDiff < -0.05) {
                          showAlert('Split Mismatch', `Exact splits are over by ₹${Math.abs(exactDiff).toFixed(2)}.`);
                          return;
                        }
                        if (splitType === 'percentage' && percentDiff < -0.5) {
                          showAlert('Percentage Mismatch', `Percentages are over by ${Math.abs(percentDiff).toFixed(1)}%.`);
                          return;
                        }
                        if (splitType === 'shares' && totalSharesCount <= 0) {
                          showAlert('No Shares', 'Please assign at least 1 share across members.');
                          return;
                        }
                        if (splitType === 'adjustment' && remainingForAdjustment < 0) {
                          showAlert('Adjustments Exceed Total', `Adjustments exceed total by ₹${Math.abs(remainingForAdjustment).toFixed(2)}.`);
                          return;
                        }
                      }
                      setCurrentView('main');
                    }}
                    className="p-2 rounded-xl"
                  >
                    <Ionicons name="checkmark" size={26} color={isSplitValid ? colors.cyan : colors.textSecondary} />
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
                      Specify exact currency amount for each person; blank fields split the remainder equally.
                    </Text>
                  )}
                  {splitType === 'percentage' && (
                    <Text className="text-xs font-semibold" style={{ color: colors.textMain }}>
                      Enter percentage share for each person; blank fields split the remaining % equally.
                    </Text>
                  )}
                  {splitType === 'shares' && (
                    <Text className="text-xs font-semibold" style={{ color: colors.textMain }}>
                      Assign shares using +/- buttons; members with 0 shares are automatically excluded.
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
                <ScrollView
                  className="flex-1 pt-1"
                  keyboardShouldPersistTaps="handled"
                  keyboardDismissMode="none"
                  showsVerticalScrollIndicator={false}
                >
                  {cohortMembers.map((m) => {
                    const name = m.profile?.nickname || m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                    const username = m.profile?.username;
                    const hasVpa = !!m.profile?.vpaId;
                    const isIncluded = includedMemberIds.includes(m.userId);
                    const memberShares = getMemberSharesCount(m.userId);

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
                            className="w-10 h-10 rounded-full items-center justify-center overflow-hidden"
                            style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                          >
                            {m.profile?.avatarUrl ? (
                              <Image source={{ uri: m.profile.avatarUrl }} className="w-10 h-10 rounded-full" />
                            ) : (
                              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                                {name.charAt(0).toUpperCase()}
                              </Text>
                            )}
                          </View>
                          <View className="flex-1">
                            <View className="flex-row items-center gap-1.5">
                              <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                                {m.userId === currentUser.id ? `${name} (You)` : name}
                              </Text>
                              {hasVpa && <Ionicons name="checkmark-circle" size={14} color={colors.cyan} />}
                            </View>
                            {username ? (
                              <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                                @{username}
                              </Text>
                            ) : null}

                            {/* Under Name Subtitle - Money They Owe */}
                            {splitType === 'exact' && (
                              <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                                ₹{getMemberExactAmount(m.userId).toFixed(2)}
                              </Text>
                            )}
                            {splitType === 'percentage' && (
                              <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                                ₹{((getMemberPercent(m.userId) / 100) * totalAmount).toFixed(2)}
                              </Text>
                            )}
                            {splitType === 'shares' && (
                              <Text
                                className="text-xs font-semibold"
                                style={{ color: memberShares === 0 ? colors.textSecondary : colors.emerald }}
                              >
                                {memberShares === 0 ? '₹0.00 (Excluded)' : `₹${getMemberShareAmount(m.userId).toFixed(2)}`}
                              </Text>
                            )}
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
                              key={`exact_${m.userId}`}
                              className="w-24 px-2 text-right text-base font-bold"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1.5,
                                borderBottomColor: colors.border,
                                minHeight: 48,
                                height: 48,
                                textAlignVertical: 'center',
                              }}
                              placeholder={placeholderExactPerPerson}
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={exactSplits[m.userId] || ''}
                              onChangeText={(text) => setExactSplits({ ...exactSplits, [m.userId]: text })}
                              multiline={false}
                              scrollEnabled={false}
                            />
                          </View>
                        )}

                        {/* Percentage: Input */}
                        {splitType === 'percentage' && (
                          <View className="flex-row items-center gap-2">
                            <TextInput
                              key={`pct_${m.userId}`}
                              className="w-16 px-2 text-right text-base font-bold"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1.5,
                                borderBottomColor: colors.border,
                                minHeight: 48,
                                height: 48,
                                textAlignVertical: 'center',
                              }}
                              placeholder={placeholderPercentPerPerson}
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={percentSplits[m.userId] || ''}
                              onChangeText={(text) => setPercentSplits({ ...percentSplits, [m.userId]: text })}
                              multiline={false}
                              scrollEnabled={false}
                            />
                            <Text className="text-base font-bold" style={{ color: colors.textSecondary }}>
                              %
                            </Text>
                          </View>
                        )}

                        {/* Shares: Stepper with [-] and [+] Buttons */}
                        {splitType === 'shares' && (
                          <View className="flex-row items-center gap-2">
                            <TouchableOpacity
                              className="w-9 h-9 rounded-xl items-center justify-center shadow-sm"
                              style={{
                                backgroundColor: memberShares > 0 ? colors.accentPill : colors.surface,
                                borderWidth: 1,
                                borderColor: colors.border,
                              }}
                              onPress={() => handleShareDecrement(m.userId)}
                              activeOpacity={0.7}
                            >
                              <Ionicons name="remove" size={18} color={memberShares > 0 ? colors.cyan : colors.textSecondary} />
                            </TouchableOpacity>

                            <View
                              className="w-10 h-9 items-center justify-center rounded-xl"
                              style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                            >
                              <Text className="text-sm font-extrabold" style={{ color: colors.textMain }}>
                                {memberShares}
                              </Text>
                            </View>

                            <TouchableOpacity
                              className="w-9 h-9 rounded-xl items-center justify-center shadow-sm"
                              style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                              onPress={() => handleShareIncrement(m.userId)}
                              activeOpacity={0.7}
                            >
                              <Ionicons name="add" size={18} color={colors.cyan} />
                            </TouchableOpacity>

                            <Text className="text-xs font-semibold ml-1" style={{ color: colors.textSecondary }}>
                              {memberShares === 1 ? 'share' : 'shares'}
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
                              className="w-20 px-2 text-right text-base font-bold"
                              style={{
                                color: colors.textMain,
                                borderBottomWidth: 1.5,
                                borderBottomColor: colors.cyan,
                                minHeight: 48,
                                height: 48,
                                textAlignVertical: 'center',
                              }}
                              placeholder="0.00"
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={adjustmentSplits[m.userId] || ''}
                              onChangeText={(text) => setAdjustmentSplits({ ...adjustmentSplits, [m.userId]: text })}
                              multiline={false}
                              scrollEnabled={false}
                            />
                          </View>
                        )}
                      </View>
                    );
                  })}
                </ScrollView>
              </View>

              {/* Bottom Summary Bar & Real-Time Validation Banner */}
              <View
                className="px-5 py-4 gap-2"
                style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
              >
                <View className="flex-row items-center justify-between">
                  <View className="flex-1 pr-2">
                    {splitType === 'equal' && (
                      <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                        ~₹{equalPerPerson}/person{' '}
                        <Text className="text-xs font-normal" style={{ color: colors.textSecondary }}>
                          ({includedMemberIds.length} {includedMemberIds.length === 1 ? 'person' : 'people'})
                        </Text>
                      </Text>
                    )}
                    {splitType === 'exact' && (
                      <View>
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                          ₹{enteredExactSum.toFixed(2)} of ₹{totalAmount.toFixed(2)}
                        </Text>
                        <Text
                          className="text-[11px] font-semibold mt-0.5"
                          style={{
                            color:
                              exactDiff === 0 || Math.abs(exactDiff) <= 0.05
                                ? colors.emerald
                                : exactDiff < 0
                                ? colors.red
                                : colors.amber,
                          }}
                        >
                          {exactDiff === 0 || Math.abs(exactDiff) <= 0.05
                            ? 'Balanced'
                            : exactDiff < 0
                            ? `Over by ₹${Math.abs(exactDiff).toFixed(2)}`
                            : `₹${exactDiff.toFixed(2)} remaining`}
                        </Text>
                      </View>
                    )}
                    {splitType === 'percentage' && (
                      <View>
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                          {enteredPercentSum.toFixed(1)}% of 100%
                        </Text>
                        <Text
                          className="text-[11px] font-semibold mt-0.5"
                          style={{
                            color:
                              percentDiff === 0 || Math.abs(percentDiff) <= 0.5
                                ? colors.emerald
                                : percentDiff < 0
                                ? colors.red
                                : colors.amber,
                          }}
                        >
                          {percentDiff === 0 || Math.abs(percentDiff) <= 0.5
                            ? 'Balanced (100%)'
                            : percentDiff < 0
                            ? `Over by ${Math.abs(percentDiff).toFixed(1)}%`
                            : `${percentDiff.toFixed(1)}% remaining`}
                        </Text>
                      </View>
                    )}
                    {splitType === 'shares' && (
                      <Text className="text-xs font-bold" style={{ color: colors.textSecondary }}>
                        Proportional distribution ({totalSharesCount} active {totalSharesCount === 1 ? 'share' : 'shares'})
                      </Text>
                    )}
                    {splitType === 'adjustment' && (
                      <View>
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                          {remainingForAdjustment >= 0
                            ? `Remainder: ₹${remainingForAdjustment.toFixed(2)} (~₹${baseAdjustmentShare.toFixed(2)}/person)`
                            : `Adjustments exceed total by ₹${Math.abs(remainingForAdjustment).toFixed(2)}`}
                        </Text>
                        <Text className="text-[10px] font-semibold" style={{ color: remainingForAdjustment >= 0 ? colors.cyan : colors.red }}>
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

                {/* 1-Tap Auto-Balance Button */}
                {splitType === 'exact' && exactDiff > 0.05 && (
                  <TouchableOpacity
                    className="py-2 px-3 rounded-xl items-center self-center"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={autoBalanceExactSplits}
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                      Distribute remaining ₹{exactDiff.toFixed(2)} equally
                    </Text>
                  </TouchableOpacity>
                )}

                {splitType === 'percentage' && percentDiff > 0.5 && (
                  <TouchableOpacity
                    className="py-2 px-3 rounded-xl items-center self-center"
                    style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                    onPress={autoBalancePercentSplits}
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                      Distribute remaining {percentDiff.toFixed(1)}% equally
                    </Text>
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
        </SafeAreaView>
      </View>
    </Modal>
  );
}

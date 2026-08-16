import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  Alert,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { compressReceiptImage } from '@/utils/imageCompressor';
import { SplitType, ExpenseSplit, Expense } from '@/types';

import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';

interface AddExpenseModalProps {
  visible: boolean;
  onClose: () => void;
  cohortId?: string;
}

export function AddExpenseModal({ visible, onClose, cohortId }: AddExpenseModalProps) {
  const theme = useTheme();
  const { cohorts, members, currentUser, addExpense } = useExpenseStore();

  const selectedCohortId = cohortId || cohorts[0]?.id || '';
  const currentCohort = cohorts.find((c) => c.id === selectedCohortId);
  const cohortMembers = members[selectedCohortId] || [];

  const [title, setTitle] = useState('');
  const [totalAmountStr, setTotalAmountStr] = useState('');
  const [category, setCategory] = useState('Dining');
  const [customCategoryName, setCustomCategoryName] = useState('');
  const [customIcon, setCustomIcon] = useState('cart');
  const [paidByUserId, setPaidByUserId] = useState(currentUser.id);
  const [splitType, setSplitType] = useState<SplitType>('equal');

  // Split state overrides
  const [exactSplits, setExactSplits] = useState<Record<string, string>>({});
  const [percentSplits, setPercentSplits] = useState<Record<string, string>>({});
  const [shareSplits, setShareSplits] = useState<Record<string, string>>({});

  const [receiptUri, setReceiptUri] = useState<string | null>(null);

  const categories = ['Dining', 'Transport', 'Accommodation', 'Utilities', 'Entertainment', 'Custom'];

  const totalAmount = parseFloat(totalAmountStr) || 0;

  // Real-time automatic auto-fill calculation helpers
  const getAutoCalculatedExact = (userId: string) => {
    if (exactSplits[userId] !== undefined && exactSplits[userId] !== '') {
      return exactSplits[userId];
    }
    // Calculate remaining sum divided by unentered members
    let enteredSum = 0;
    let unenteredCount = 0;

    cohortMembers.forEach((m) => {
      if (exactSplits[m.userId] !== undefined && exactSplits[m.userId] !== '') {
        enteredSum += parseFloat(exactSplits[m.userId]) || 0;
      } else {
        unenteredCount++;
      }
    });

    if (unenteredCount <= 0) return '0.00';
    const remaining = Math.max(0, totalAmount - enteredSum);
    return (remaining / unenteredCount).toFixed(2);
  };

  const getAutoCalculatedPercent = (userId: string) => {
    if (percentSplits[userId] !== undefined && percentSplits[userId] !== '') {
      return percentSplits[userId];
    }
    let enteredPct = 0;
    let unenteredCount = 0;

    cohortMembers.forEach((m) => {
      if (percentSplits[m.userId] !== undefined && percentSplits[m.userId] !== '') {
        enteredPct += parseFloat(percentSplits[m.userId]) || 0;
      } else {
        unenteredCount++;
      }
    });

    if (unenteredCount <= 0) return '0';
    const remainingPct = Math.max(0, 100 - enteredPct);
    return (remainingPct / unenteredCount).toFixed(1);
  };

  const handlePickReceipt = async () => {
    try {
      const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!permission.granted) {
        Alert.alert('Permission required', 'Gallery access is needed to pick receipt photos.');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        quality: 0.8,
      });

      if (!result.canceled && result.assets?.[0]?.uri) {
        const compressed = await compressReceiptImage(result.assets[0].uri);
        setReceiptUri(compressed);
      }
    } catch (err) {
      console.warn('Image picker error:', err);
    }
  };

  const handleSave = () => {
    if (!title.trim() || isNaN(totalAmount) || totalAmount <= 0) {
      Alert.alert('Invalid Input', 'Please enter a valid title and total amount.');
      return;
    }

    if (cohortMembers.length === 0) {
      Alert.alert('Error', 'No members found in this event cohort.');
      return;
    }

    let calculatedSplits: ExpenseSplit[] = [];

    if (splitType === 'equal') {
      const perPerson = Math.round((totalAmount / cohortMembers.length) * 100) / 100;
      calculatedSplits = cohortMembers.map((m) => ({
        userId: m.userId,
        amount: perPerson,
      }));
    } else if (splitType === 'exact') {
      calculatedSplits = cohortMembers.map((m) => {
        const amt = parseFloat(getAutoCalculatedExact(m.userId)) || 0;
        return { userId: m.userId, amount: Math.round(amt * 100) / 100 };
      });
    } else if (splitType === 'percentage') {
      calculatedSplits = cohortMembers.map((m) => {
        const pct = parseFloat(getAutoCalculatedPercent(m.userId)) || 0;
        return {
          userId: m.userId,
          amount: Math.round((totalAmount * (pct / 100)) * 100) / 100,
          percentage: pct,
        };
      });
    } else if (splitType === 'shares') {
      let totalShares = 0;
      const memberShareNums: Record<string, number> = {};

      cohortMembers.forEach((m) => {
        const sh = parseFloat(shareSplits[m.userId] || '1') || 0;
        memberShareNums[m.userId] = sh;
        totalShares += sh;
      });

      if (totalShares <= 0) {
        Alert.alert('Shares Required', 'Total shares must be greater than 0.');
        return;
      }

      calculatedSplits = cohortMembers.map((m) => {
        const sh = memberShareNums[m.userId];
        const amt = Math.round((totalAmount * (sh / totalShares)) * 100) / 100;
        return {
          userId: m.userId,
          amount: amt,
          percentage: Math.round((sh / totalShares) * 1000) / 10,
        };
      });
    }

    const finalCategory = category === 'Custom' ? (customCategoryName.trim() || 'custom') : category.toLowerCase();

    const newExpense: Expense = {
      id: `exp_${Date.now()}`,
      cohortId: selectedCohortId,
      title: title.trim(),
      category: finalCategory,
      customIcon: category === 'Custom' ? customIcon : undefined,
      totalAmount,
      currency: currentCohort?.currency || 'INR',
      paidByUserId,
      splitType,
      splits: calculatedSplits,
      receiptUrl: receiptUri || undefined,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    addExpense(newExpense);
    onClose();
    resetForm();
  };

  const resetForm = () => {
    setTitle('');
    setTotalAmountStr('');
    setCustomCategoryName('');
    setReceiptUri(null);
    setExactSplits({});
    setPercentSplits({});
    setShareSplits({});
    setCustomIcon('cart');
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View style={styles.backdrop}>
        <View style={[styles.card, { backgroundColor: theme.backgroundElement }]}>
          {/* Header */}
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: theme.text }]}>Add Expense</Text>
            <TouchableOpacity onPress={onClose}>
              <Text style={[styles.closeX, { color: theme.textSecondary }]}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.formContent}>
            {/* Title Input */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>DESCRIPTION</Text>
            <TextInput
              style={[styles.input, { backgroundColor: theme.backgroundSelected, color: theme.text }]}
              placeholder="e.g. Dinner, Fuel, Groceries"
              placeholderTextColor={theme.textSecondary}
              value={title}
              onChangeText={setTitle}
            />

            {/* Total Amount Input */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>TOTAL AMOUNT (₹)</Text>
            <TextInput
              style={[styles.input, styles.amountInput, { backgroundColor: theme.backgroundSelected, color: theme.text }]}
              placeholder="0.00"
              placeholderTextColor={theme.textSecondary}
              keyboardType="decimal-pad"
              value={totalAmountStr}
              onChangeText={setTotalAmountStr}
            />

            {/* Category Selector */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>CATEGORY</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipsRow}>
              {categories.map((cat) => (
                <TouchableOpacity
                  key={cat}
                  style={[
                    styles.chip,
                    category === cat ? styles.chipActive : { backgroundColor: theme.backgroundSelected },
                  ]}
                  onPress={() => setCategory(cat)}
                >
                  <Text style={[styles.chipText, category === cat ? styles.chipTextActive : { color: theme.text }]}>
                    {cat}
                  </Text>
                </TouchableOpacity>
              ))}
            </ScrollView>

            {/* Custom Category Input & Icon Picker */}
            {category === 'Custom' && (
              <View style={styles.customPickerBox}>
                <Text style={[styles.subLabel, { color: theme.text }]}>Custom Category Name:</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: theme.backgroundElement, color: theme.text, marginBottom: 12 }]}
                  placeholder="e.g. Badminton, Movie Night, Snacks"
                  placeholderTextColor={theme.textSecondary}
                  value={customCategoryName}
                  onChangeText={setCustomCategoryName}
                />

                <Text style={[styles.subLabel, { color: theme.text }]}>Choose Category Icon:</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.iconGrid}>
                  {GENERIC_CUSTOM_ICONS.map((item) => {
                    const isSelected = customIcon === item.name;
                    return (
                      <TouchableOpacity
                        key={item.name}
                        style={[
                          styles.iconPickTile,
                          isSelected ? styles.iconPickTileActive : { backgroundColor: theme.backgroundSelected },
                        ]}
                        onPress={() => setCustomIcon(item.name)}
                      >
                        <Ionicons
                          name={item.name}
                          size={18}
                          color={isSelected ? '#FFFFFF' : theme.text}
                        />
                        <Text
                          style={[
                            styles.iconPickText,
                            isSelected ? { color: '#FFFFFF' } : { color: theme.textSecondary },
                          ]}
                        >
                          {item.label}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
              </View>
            )}

            {/* Paid By Selector */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>PAID BY</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chipsRow}>
              {cohortMembers.map((m) => {
                const name = m.profile?.fullName || m.userId;
                const isSelected = paidByUserId === m.userId;
                return (
                  <TouchableOpacity
                    key={m.userId}
                    style={[
                      styles.chip,
                      isSelected ? styles.chipActive : { backgroundColor: theme.backgroundSelected },
                    ]}
                    onPress={() => setPaidByUserId(m.userId)}
                  >
                    <Text style={[styles.chipText, isSelected ? styles.chipTextActive : { color: theme.text }]}>
                      {m.userId === currentUser.id ? 'You' : name}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>

            {/* Split Type Sub-Tabs */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>SPLIT ALLOCATION TYPE</Text>
            <View style={styles.splitRow}>
              {(['equal', 'exact', 'percentage', 'shares'] as SplitType[]).map((type) => (
                <TouchableOpacity
                  key={type}
                  style={[
                    styles.splitBtn,
                    splitType === type ? styles.splitBtnActive : { backgroundColor: theme.backgroundSelected },
                  ]}
                  onPress={() => setSplitType(type)}
                >
                  <Text
                    style={[
                      styles.splitBtnText,
                      splitType === type ? styles.splitBtnTextActive : { color: theme.text },
                    ]}
                  >
                    {type.toUpperCase()}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Dedicated Sub-View for Selected Split Type */}
            <View style={[styles.splitSubView, { backgroundColor: theme.backgroundSelected }]}>
              {splitType === 'equal' && (
                <Text style={[styles.splitNotice, { color: theme.textSecondary }]}>
                  Split equally: ₹
                  {(
                    totalAmount / Math.max(cohortMembers.length, 1)
                  ).toFixed(2)}{' '}
                  per member ({cohortMembers.length} members).
                </Text>
              )}

              {splitType === 'exact' && (
                <View style={styles.memberInputsList}>
                  <View style={styles.splitHeaderRow}>
                    <Text style={[styles.splitSubHeader, { color: theme.text }]}>Exact Amounts (₹)</Text>
                    <Text style={[styles.autoNoticeText, { color: '#10B981' }]}>⚡ Auto-filling remaining</Text>
                  </View>

                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || m.userId;
                    const val = getAutoCalculatedExact(m.userId);

                    return (
                      <View key={m.userId} style={styles.memberInputRow}>
                        <Text style={[styles.memberName, { color: theme.text }]}>
                          {m.userId === currentUser.id ? 'You' : name}
                        </Text>
                        <TextInput
                          style={[styles.smallInput, { backgroundColor: theme.backgroundElement, color: theme.text }]}
                          placeholder="0.00"
                          placeholderTextColor={theme.textSecondary}
                          keyboardType="decimal-pad"
                          value={exactSplits[m.userId] !== undefined ? exactSplits[m.userId] : val}
                          onChangeText={(v) => setExactSplits({ ...exactSplits, [m.userId]: v })}
                        />
                      </View>
                    );
                  })}
                </View>
              )}

              {splitType === 'percentage' && (
                <View style={styles.memberInputsList}>
                  <View style={styles.splitHeaderRow}>
                    <Text style={[styles.splitSubHeader, { color: theme.text }]}>Percentages (%)</Text>
                    <Text style={[styles.autoNoticeText, { color: '#10B981' }]}>⚡ Auto-filling remaining</Text>
                  </View>

                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || m.userId;
                    const val = getAutoCalculatedPercent(m.userId);

                    return (
                      <View key={m.userId} style={styles.memberInputRow}>
                        <Text style={[styles.memberName, { color: theme.text }]}>
                          {m.userId === currentUser.id ? 'You' : name}
                        </Text>
                        <TextInput
                          style={[styles.smallInput, { backgroundColor: theme.backgroundElement, color: theme.text }]}
                          placeholder="0%"
                          placeholderTextColor={theme.textSecondary}
                          keyboardType="decimal-pad"
                          value={percentSplits[m.userId] !== undefined ? percentSplits[m.userId] : val}
                          onChangeText={(v) => setPercentSplits({ ...percentSplits, [m.userId]: v })}
                        />
                      </View>
                    );
                  })}
                </View>
              )}

              {splitType === 'shares' && (
                <View style={styles.memberInputsList}>
                  <View style={styles.splitHeaderRow}>
                    <Text style={[styles.splitSubHeader, { color: theme.text }]}>Shares / Ratios (Decimals OK)</Text>
                  </View>

                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || m.userId;
                    const shVal = parseFloat(shareSplits[m.userId] || '1') || 0;
                    let totalSh = 0;
                    cohortMembers.forEach((mem) => {
                      totalSh += parseFloat(shareSplits[mem.userId] || '1') || 0;
                    });
                    const computedAmt = (totalAmount * (shVal / Math.max(totalSh, 1))).toFixed(2);

                    return (
                      <View key={m.userId} style={styles.memberInputRow}>
                        <View>
                          <Text style={[styles.memberName, { color: theme.text }]}>
                            {m.userId === currentUser.id ? 'You' : name}
                          </Text>
                          <Text style={[styles.computedShareText, { color: theme.textSecondary }]}>
                            Calculated: ₹{computedAmt}
                          </Text>
                        </View>
                        <TextInput
                          style={[styles.smallInput, { backgroundColor: theme.backgroundElement, color: theme.text }]}
                          placeholder="1.0"
                          placeholderTextColor={theme.textSecondary}
                          keyboardType="decimal-pad"
                          value={shareSplits[m.userId] ?? '1'}
                          onChangeText={(val) => setShareSplits({ ...shareSplits, [m.userId]: val })}
                        />
                      </View>
                    );
                  })}
                </View>
              )}
            </View>

            {/* Receipt Image Attachment */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>RECEIPT ATTACHMENT</Text>
            <View style={styles.receiptBox}>
              {receiptUri ? (
                <View style={styles.receiptPreview}>
                  <Image source={{ uri: receiptUri }} style={styles.receiptImg} />
                  <TouchableOpacity style={styles.removeReceipt} onPress={() => setReceiptUri(null)}>
                    <Text style={styles.removeReceiptText}>Remove</Text>
                  </TouchableOpacity>
                </View>
              ) : (
                <TouchableOpacity style={[styles.addReceiptBtn, { backgroundColor: theme.backgroundSelected }]} onPress={handlePickReceipt}>
                  <Text style={[styles.addReceiptText, { color: theme.text }]}>📷 Attach Receipt Photo</Text>
                </TouchableOpacity>
              )}
            </View>

            {/* Submit Button */}
            <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
              <Text style={styles.saveBtnText}>Save Expense</Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'flex-end',
  },
  card: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '90%',
    padding: 20,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '800',
  },
  closeX: {
    fontSize: 20,
    fontWeight: '700',
    padding: 4,
  },
  formContent: {
    gap: 12,
    paddingBottom: 24,
  },
  label: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.5,
    marginTop: 4,
  },
  input: {
    height: 44,
    borderRadius: 12,
    paddingHorizontal: 14,
    fontSize: 15,
  },
  amountInput: {
    fontSize: 22,
    fontWeight: '700',
  },
  chipsRow: {
    gap: 8,
  },
  chip: {
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 20,
  },
  chipActive: {
    backgroundColor: '#6366F1',
  },
  chipText: {
    fontSize: 13,
    fontWeight: '600',
  },
  chipTextActive: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
  splitRow: {
    flexDirection: 'row',
    gap: 6,
  },
  splitBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
  },
  splitBtnActive: {
    backgroundColor: '#6366F1',
  },
  splitBtnText: {
    fontSize: 11,
    fontWeight: '700',
  },
  splitBtnTextActive: {
    color: '#FFFFFF',
  },
  splitSubView: {
    padding: 14,
    borderRadius: 14,
    marginTop: 4,
  },
  splitNotice: {
    fontSize: 13,
    fontStyle: 'italic',
  },
  splitHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  splitSubHeader: {
    fontSize: 13,
    fontWeight: '700',
  },
  autoNoticeText: {
    fontSize: 11,
    fontWeight: '700',
  },
  memberInputsList: {
    gap: 8,
  },
  memberInputRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  memberName: {
    fontSize: 14,
    fontWeight: '600',
  },
  computedShareText: {
    fontSize: 11,
    marginTop: 2,
  },
  smallInput: {
    width: 80,
    height: 36,
    borderRadius: 8,
    paddingHorizontal: 10,
    fontSize: 14,
    textAlign: 'right',
  },
  receiptBox: {
    marginTop: 4,
  },
  addReceiptBtn: {
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
  },
  addReceiptText: {
    fontWeight: '700',
    fontSize: 14,
  },
  receiptPreview: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  receiptImg: {
    width: 60,
    height: 60,
    borderRadius: 8,
  },
  removeReceipt: {
    backgroundColor: '#EF4444',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 8,
  },
  removeReceiptText: {
    color: '#FFF',
    fontWeight: '700',
    fontSize: 12,
  },
  saveBtn: {
    backgroundColor: '#6366F1',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    marginTop: 16,
  },
  saveBtnText: {
    color: '#FFFFFF',
    fontWeight: '800',
    fontSize: 16,
  },
  customPickerBox: {
    marginTop: 6,
    marginBottom: 4,
  },
  subLabel: {
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 6,
  },
  iconGrid: {
    gap: 8,
    paddingRight: 16,
  },
  iconPickTile: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 60,
    height: 52,
    borderRadius: 10,
    gap: 2,
  },
  iconPickTileActive: {
    backgroundColor: '#EC4899',
  },
  iconPickText: {
    fontSize: 10,
    fontWeight: '600',
  },
});

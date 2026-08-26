import React, { useState, useEffect } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  Alert,
  StatusBar,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as ImagePicker from 'expo-image-picker';
import { useExpenseStore } from '@/store/useExpenseStore';
import { compressReceiptImage } from '@/utils/imageCompressor';
import { SplitType, ExpenseSplit, Expense } from '@/types';

import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface AddExpenseModalProps {
  visible: boolean;
  onClose: () => void;
  cohortId?: string;
}

export function AddExpenseModal({ visible, onClose, cohortId }: AddExpenseModalProps) {
  const { cohorts, members, currentUser, addExpense } = useExpenseStore();

  const activeCohortId = cohortId || cohorts[0]?.id || '';
  const currentCohort = cohorts.find((c) => c.id === activeCohortId) || cohorts[0];
  const cohortMembers = members[activeCohortId] || (currentCohort ? members[currentCohort.id] : []) || [];

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
        mediaTypes: ['images'],
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
      cohortId: activeCohortId,
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
    <Modal visible={visible} animationType="slide" presentationStyle="fullScreen" onRequestClose={onClose}>
      <SafeAreaView className="flex-1 bg-slate-50">
        <StatusBar barStyle="dark-content" />
        
        {/* Full Screen Top Navigation Bar */}
        <View className="flex-row justify-between items-center px-6 py-4 bg-white border-b border-slate-200">
          <TouchableOpacity
            className="w-10 h-10 rounded-full bg-slate-100 items-center justify-center border border-slate-200"
            onPress={onClose}
          >
            <Ionicons name="close" size={22} color="#0F172A" />
          </TouchableOpacity>
          <Text className="text-lg font-black text-slate-900">Add Expense</Text>
          <TouchableOpacity
            className="px-4 py-2 rounded-xl bg-slate-900"
            onPress={handleSave}
          >
            <Text className="text-white text-xs font-bold">Save</Text>
          </TouchableOpacity>
        </View>

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerClassName="p-6 gap-6 pb-20"
        >

          {/* HERO AMOUNT CARD - MASSIVE PRICE TEXTBOX */}
          <View className="card-main p-6 items-center justify-center bg-white shadow-sm">
            <Text className="text-xs font-extrabold text-slate-400 uppercase tracking-widest mb-2">
              ENTER TOTAL AMOUNT
            </Text>
            <View className="flex-row items-center justify-center w-full py-3">
              <Text className="text-4xl font-extrabold text-slate-400 mr-2">₹</Text>
              <TextInput
                className="text-5xl font-black text-slate-900 min-w-[160px] text-center tracking-tight"
                placeholder="0.00"
                placeholderTextColor="#CBD5E1"
                keyboardType="decimal-pad"
                autoFocus={true}
                cursorColor="transparent"
                caretHidden={true}
                value={totalAmountStr}
                onChangeText={setTotalAmountStr}
              />
            </View>
            <Text className="text-xs text-slate-500 font-medium mt-1">
              Ledger: <Text className="font-bold text-slate-800">{currentCohort?.name || 'Group'}</Text>
            </Text>
          </View>

          {/* DESCRIPTION SECTION */}
          <View className="card-main p-5 gap-3 bg-white">
            <Text className="section-label">DESCRIPTION / TITLE</Text>
            <View className="flex-row items-center bg-slate-50 border border-slate-200 rounded-2xl px-4 py-1">
              <Ionicons name="receipt-outline" size={20} color="#64748B" />
              <TextInput
                className="flex-1 h-12 text-base font-semibold text-slate-900 ml-2"
                placeholder="e.g. Seafood Dinner, Villa Rental, Grocery"
                placeholderTextColor="#94A3B8"
                multiline={false}
                numberOfLines={1}
                returnKeyType="done"
                value={title}
                onChangeText={setTitle}
              />
            </View>
          </View>

          {/* CATEGORY SECTION */}
          <View className="card-main p-5 gap-3.5 bg-white">
            <Text className="section-label">EXPENSE CATEGORY</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2.5">
              {categories.map((cat) => {
                const isSelected = category === cat;
                return (
                  <TouchableOpacity
                    key={cat}
                    className={`px-5 py-3 rounded-2xl border flex-row items-center gap-2 ${
                      isSelected ? 'bg-slate-900 border-slate-900' : 'bg-slate-50 border-slate-200'
                    }`}
                    onPress={() => setCategory(cat)}
                  >
                    <Text
                      className={`text-sm font-bold ${
                        isSelected ? 'text-white' : 'text-slate-700'
                      }`}
                    >
                      {cat}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>

            {/* Custom Category Details */}
            {category === 'Custom' && (
              <View className="p-4 bg-slate-50 border border-slate-200 rounded-2xl gap-3 mt-1">
                <Text className="text-xs font-bold text-slate-700">Custom Category Name:</Text>
                <TextInput
                  className="h-11 bg-white border border-slate-200 rounded-xl px-3.5 text-sm text-slate-900 font-medium"
                  placeholder="e.g. Badminton Club, Movie Night, Snacks"
                  placeholderTextColor="#94A3B8"
                  multiline={false}
                  numberOfLines={1}
                  value={customCategoryName}
                  onChangeText={setCustomCategoryName}
                />

                <Text className="text-xs font-bold text-slate-700 mt-1">Choose Icon:</Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2.5 pr-4">
                  {GENERIC_CUSTOM_ICONS.map((item) => {
                    const isSelected = customIcon === item.name;
                    return (
                      <TouchableOpacity
                        key={item.name}
                        className={`items-center justify-center w-14 h-14 rounded-2xl border ${
                          isSelected ? 'bg-slate-900 border-slate-900 shadow-sm' : 'bg-white border-slate-200'
                        }`}
                        onPress={() => setCustomIcon(item.name)}
                      >
                        <Ionicons
                          name={item.name}
                          size={22}
                          color={isSelected ? '#FFFFFF' : '#475569'}
                        />
                        <Text
                          className={`text-[9px] font-bold mt-1 ${
                            isSelected ? 'text-white' : 'text-slate-500'
                          }`}
                        >
                          {item.label}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
              </View>
            )}
          </View>

          {/* PAID BY SECTION */}
          <View className="card-main p-5 gap-3.5 bg-white">
            <Text className="section-label">PAID BY</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2.5">
              {cohortMembers.map((m) => {
                const name = m.profile?.fullName || m.userId;
                const isSelected = paidByUserId === m.userId;
                return (
                  <TouchableOpacity
                    key={m.userId}
                    className={`px-4 py-2.5 rounded-2xl border flex-row items-center gap-2 ${
                      isSelected ? 'bg-slate-900 border-slate-900' : 'bg-slate-50 border-slate-200'
                    }`}
                    onPress={() => setPaidByUserId(m.userId)}
                  >
                    <View className={`w-6 h-6 rounded-full items-center justify-center ${isSelected ? 'bg-slate-800' : 'bg-slate-200'}`}>
                      <Text className={`text-[10px] font-bold ${isSelected ? 'text-white' : 'text-slate-700'}`}>
                        {name.charAt(0).toUpperCase()}
                      </Text>
                    </View>
                    <Text
                      className={`text-xs font-bold ${
                        isSelected ? 'text-white' : 'text-slate-700'
                      }`}
                    >
                      {m.userId === currentUser.id ? 'You' : name}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          </View>

          {/* SPLIT ALLOCATION SECTION */}
          <View className="card-main p-5 gap-4 bg-white">
            <Text className="section-label">SPLIT ALLOCATION TYPE</Text>
            <View className="flex-row gap-2">
              {(['equal', 'exact', 'percentage', 'shares'] as SplitType[]).map((type) => {
                const isSelected = splitType === type;
                return (
                  <TouchableOpacity
                    key={type}
                    className={`flex-1 py-3 rounded-2xl items-center border ${
                      isSelected ? 'bg-slate-900 border-slate-900' : 'bg-slate-50 border-slate-200'
                    }`}
                    onPress={() => setSplitType(type)}
                  >
                    <Text
                      className={`text-[11px] font-extrabold tracking-wider ${
                        isSelected ? 'text-white' : 'text-slate-700'
                      }`}
                    >
                      {type.toUpperCase()}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>

            {/* Sub-view for Split Calculation */}
            <View className="p-4 bg-slate-50 border border-slate-200 rounded-2xl mt-1">
              {splitType === 'equal' && (
                <View className="gap-1 py-1">
                  <Text className="text-sm font-semibold text-slate-800">
                    Split evenly among all members:
                  </Text>
                  <Text className="text-2xl font-black text-slate-900 mt-1">
                    ₹{(totalAmount / Math.max(cohortMembers.length, 1)).toFixed(2)}
                    <Text className="text-xs font-normal text-slate-500"> / person ({cohortMembers.length} members)</Text>
                  </Text>
                </View>
              )}

              {splitType === 'exact' && (
                <View className="gap-3">
                  <View className="flex-row justify-between items-center mb-1">
                    <Text className="text-xs font-bold text-slate-900">Exact Amounts (₹)</Text>
                    <Text className="text-[10px] font-bold text-emerald-600">⚡ Auto-filling remaining</Text>
                  </View>

                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || m.userId;
                    const val = getAutoCalculatedExact(m.userId);

                    return (
                      <View key={m.userId} className="flex-row justify-between items-center py-1">
                        <View className="flex-row items-center gap-2">
                          <View className="w-7 h-7 rounded-full bg-slate-200 items-center justify-center">
                            <Text className="text-[10px] font-bold text-slate-700">{name.charAt(0).toUpperCase()}</Text>
                          </View>
                          <Text className="text-sm font-semibold text-slate-800">
                            {m.userId === currentUser.id ? 'You' : name}
                          </Text>
                        </View>
                        <TextInput
                          className="w-28 h-10 bg-white border border-slate-200 rounded-xl px-3 text-sm font-bold text-slate-900 text-center shadow-sm"
                          placeholder="0.00"
                          placeholderTextColor="#94A3B8"
                          keyboardType="decimal-pad"
                          cursorColor="transparent"
                          caretHidden={true}
                          value={exactSplits[m.userId] !== undefined ? exactSplits[m.userId] : val}
                          onChangeText={(v) => setExactSplits({ ...exactSplits, [m.userId]: v })}
                        />
                      </View>
                    );
                  })}
                </View>
              )}

              {splitType === 'percentage' && (
                <View className="gap-3">
                  <View className="flex-row justify-between items-center mb-1">
                    <Text className="text-xs font-bold text-slate-900">Percentages (%)</Text>
                    <Text className="text-[10px] font-bold text-emerald-600">⚡ Auto-filling remaining</Text>
                  </View>

                  {cohortMembers.map((m) => {
                    const name = m.profile?.fullName || m.userId;
                    const val = getAutoCalculatedPercent(m.userId);

                    return (
                      <View key={m.userId} className="flex-row justify-between items-center py-1">
                        <View className="flex-row items-center gap-2">
                          <View className="w-7 h-7 rounded-full bg-slate-200 items-center justify-center">
                            <Text className="text-[10px] font-bold text-slate-700">{name.charAt(0).toUpperCase()}</Text>
                          </View>
                          <Text className="text-sm font-semibold text-slate-800">
                            {m.userId === currentUser.id ? 'You' : name}
                          </Text>
                        </View>
                        <TextInput
                          className="w-28 h-10 bg-white border border-slate-200 rounded-xl px-3 text-sm font-bold text-slate-900 text-center shadow-sm"
                          placeholder="0%"
                          placeholderTextColor="#94A3B8"
                          keyboardType="decimal-pad"
                          cursorColor="transparent"
                          caretHidden={true}
                          value={percentSplits[m.userId] !== undefined ? percentSplits[m.userId] : val}
                          onChangeText={(v) => setPercentSplits({ ...percentSplits, [m.userId]: v })}
                        />
                      </View>
                    );
                  })}
                </View>
              )}

              {splitType === 'shares' && (
                <View className="gap-3">
                  <View className="flex-row justify-between items-center mb-1">
                    <Text className="text-xs font-bold text-slate-900">Shares / Ratios (Decimals OK)</Text>
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
                      <View key={m.userId} className="flex-row justify-between items-center py-1">
                        <View>
                          <Text className="text-sm font-semibold text-slate-800">
                            {m.userId === currentUser.id ? 'You' : name}
                          </Text>
                          <Text className="text-xs font-bold text-emerald-600 mt-0.5">
                            Calculated: ₹{computedAmt}
                          </Text>
                        </View>
                        <TextInput
                          className="w-28 h-10 bg-white border border-slate-200 rounded-xl px-3 text-sm font-bold text-slate-900 text-center shadow-sm"
                          placeholder="1.0"
                          placeholderTextColor="#94A3B8"
                          keyboardType="decimal-pad"
                          cursorColor="transparent"
                          caretHidden={true}
                          value={shareSplits[m.userId] ?? '1'}
                          onChangeText={(val) => setShareSplits({ ...shareSplits, [m.userId]: val })}
                        />
                      </View>
                    );
                  })}
                </View>
              )}
            </View>
          </View>

          {/* RECEIPT ATTACHMENT SECTION */}
          <View className="card-main p-5 gap-3 bg-white">
            <Text className="section-label">RECEIPT ATTACHMENT</Text>
            {receiptUri ? (
              <View className="flex-row items-center gap-4 p-4 bg-slate-50 border border-slate-200 rounded-2xl">
                <Image source={{ uri: receiptUri }} className="w-16 h-16 rounded-xl" />
                <View className="flex-1">
                  <Text className="text-xs font-bold text-slate-900">Receipt Attached</Text>
                  <Text className="text-[11px] text-slate-500">Image successfully linked to payment</Text>
                </View>
                <TouchableOpacity
                  className="bg-rose-50 border border-rose-200 px-3.5 py-2 rounded-xl"
                  onPress={() => setReceiptUri(null)}
                >
                  <Text className="text-rose-600 font-bold text-xs">Remove</Text>
                </TouchableOpacity>
              </View>
            ) : (
              <TouchableOpacity
                className="py-5 bg-slate-50 border border-dashed border-slate-300 rounded-2xl items-center justify-center gap-1.5"
                onPress={handlePickReceipt}
              >
                <Ionicons name="camera-outline" size={24} color="#64748B" />
                <Text className="text-slate-700 font-bold text-sm">Attach Receipt Photo</Text>
                <Text className="text-[11px] text-slate-400">PNG, JPG, or Camera Shot</Text>
              </TouchableOpacity>
            )}
          </View>

          {/* LARGE PRIMARY SAVE BUTTON */}
          <TouchableOpacity
            className="w-full h-14 bg-slate-900 rounded-2xl items-center justify-center shadow-lg active:opacity-90 mt-2 mb-8"
            onPress={handleSave}
          >
            <Text className="text-white font-black text-lg tracking-wide">Save Expense</Text>
          </TouchableOpacity>
        </ScrollView>
      </SafeAreaView>
    </Modal>
  );
}

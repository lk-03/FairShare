import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  useColorScheme,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { ExpenseShortcut, EventCategory, SplitType, GroupMember } from '@/types';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
import { Text } from '@/components/ui/Text';

interface ShortcutManagerModalProps {
  visible: boolean;
  onClose: () => void;
  shortcut: ExpenseShortcut | null;
  cohortId: string;
}

const STANDARD_CATEGORIES: { label: string; value: EventCategory }[] = [
  { label: 'Utilities', value: 'utilities' },
  { label: 'House', value: 'house' },
  { label: 'Dining', value: 'dining' },
  { label: 'Transport', value: 'transport' },
  { label: 'Trip', value: 'trip' },
  { label: 'Event', value: 'event' },
  { label: 'Custom', value: 'custom' },
];

const SPLIT_TABS: { label: string; value: SplitType }[] = [
  { label: 'Equally', value: 'equal' },
  { label: 'Unequally', value: 'exact' },
  { label: 'By %', value: 'percentage' },
  { label: 'By Shares', value: 'shares' },
  { label: 'Adjustment', value: 'adjustment' },
];

export function ShortcutManagerModal({
  visible,
  onClose,
  shortcut,
  cohortId,
}: ShortcutManagerModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { updateShortcut, deleteShortcut, addShortcut, currentUser, members } = useExpenseStore();

  const cohortMembers = useMemo(() => {
    return members[cohortId] || [];
  }, [cohortId, members]);

  const [title, setTitle] = useState('');
  const [amountStr, setAmountStr] = useState('');
  const [category, setCategory] = useState<string>('utilities');
  const [customIcon, setCustomIcon] = useState<string>('flash');
  const [paidByUserId, setPaidByUserId] = useState<string>(currentUser.id);
  const [isMultiplePayers, setIsMultiplePayers] = useState(false);
  const [paidAmounts, setPaidAmounts] = useState<Record<string, string>>({});
  const [splitType, setSplitType] = useState<SplitType>('equal');
  const [includedMemberIds, setIncludedMemberIds] = useState<string[]>([]);
  const [exactSplits, setExactSplits] = useState<Record<string, string>>({});
  const [percentSplits, setPercentSplits] = useState<Record<string, string>>({});
  const [shareSplits, setShareSplits] = useState<Record<string, number>>({});
  const [adjustmentSplits, setAdjustmentSplits] = useState<Record<string, string>>({});

  useEffect(() => {
    if (shortcut && visible) {
      setTitle(shortcut.title || '');
      setAmountStr(shortcut.amount ? String(shortcut.amount) : '');
      setCategory(shortcut.category || 'utilities');
      setCustomIcon(shortcut.customIcon || 'flash');
      setIsMultiplePayers(shortcut.isMultiplePayers ?? false);
      setPaidAmounts(shortcut.paidAmounts || {});
      setPaidByUserId(shortcut.paidByUserId || currentUser.id);
      setSplitType(shortcut.splitType || 'equal');
      setIncludedMemberIds(
        shortcut.includedMemberIds || cohortMembers.map((m) => m.userId)
      );
      setExactSplits(shortcut.exactSplits || {});
      setPercentSplits(shortcut.percentageSplits || {});
      setShareSplits(shortcut.sharesSplits || {});
      setAdjustmentSplits(shortcut.adjustmentSplits || {});
    } else if (visible) {
      setTitle('');
      setAmountStr('');
      setCategory('utilities');
      setCustomIcon('flash');
      setIsMultiplePayers(false);
      setPaidAmounts({});
      setPaidByUserId(currentUser.id);
      setSplitType('equal');
      setIncludedMemberIds(cohortMembers.map((m) => m.userId));
      setExactSplits({});
      setPercentSplits({});
      setShareSplits(Object.fromEntries(cohortMembers.map((m) => [m.userId, 1])));
      setAdjustmentSplits({});
    }
  }, [shortcut, visible, cohortMembers, currentUser.id]);

  if (!visible) return null;

  const toggleMemberInclusion = (userId: string) => {
    if (includedMemberIds.includes(userId)) {
      if (includedMemberIds.length <= 1) {
        showAlert('At least one member', 'You must include at least one member in the shortcut.');
        return;
      }
      setIncludedMemberIds(includedMemberIds.filter((id) => id !== userId));
    } else {
      setIncludedMemberIds([...includedMemberIds, userId]);
    }
  };

  const handleShareChange = (userId: string, delta: number) => {
    const current = shareSplits[userId] ?? 1;
    const next = Math.max(0, current + delta);
    setShareSplits({ ...shareSplits, [userId]: next });
  };

  const handleSave = () => {
    if (!title.trim()) {
      showAlert('Title Required', 'Please enter a title for this shortcut.');
      return;
    }

    let numAmount = parseFloat(amountStr) || 0;

    // Smart inference if amount was left blank but exact splits or paid amounts were specified
    if (numAmount <= 0) {
      if (splitType === 'exact') {
        const exactSum = Object.values(exactSplits).reduce((sum, v) => sum + (parseFloat(v) || 0), 0);
        if (exactSum > 0) numAmount = Number(exactSum.toFixed(2));
      } else if (isMultiplePayers) {
        const paidSum = Object.values(paidAmounts).reduce((sum, v) => sum + (parseFloat(v) || 0), 0);
        if (paidSum > 0) numAmount = Number(paidSum.toFixed(2));
      }
    }

    const payload: Partial<ExpenseShortcut> = {
      title: title.trim(),
      amount: numAmount,
      category,
      customIcon,
      paidByUserId: isMultiplePayers ? undefined : paidByUserId,
      isMultiplePayers,
      paidAmounts: isMultiplePayers ? paidAmounts : undefined,
      splitType,
      includedMemberIds,
      exactSplits: splitType === 'exact' ? exactSplits : undefined,
      percentageSplits: splitType === 'percentage' ? percentSplits : undefined,
      sharesSplits: splitType === 'shares' ? shareSplits : undefined,
      adjustmentSplits: splitType === 'adjustment' ? adjustmentSplits : undefined,
    };

    if (shortcut) {
      updateShortcut(shortcut.id, cohortId, payload);
    } else {
      const newSc: ExpenseShortcut = {
        id: `sc_${Date.now()}`,
        cohortId,
        title: title.trim(),
        amount: numAmount,
        category,
        customIcon,
        paidByUserId: payload.paidByUserId,
        isMultiplePayers: payload.isMultiplePayers,
        paidAmounts: payload.paidAmounts,
        splitType,
        includedMemberIds,
        exactSplits: payload.exactSplits,
        percentageSplits: payload.percentageSplits,
        sharesSplits: payload.sharesSplits,
        adjustmentSplits: payload.adjustmentSplits,
        createdAt: new Date().toISOString(),
      };
      addShortcut(newSc);
    }
    onClose();
  };

  const handleDelete = () => {
    if (!shortcut) return;
    showAlert('Delete Shortcut', `Are you sure you want to delete "${shortcut.title}"?`, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        icon: 'trash-outline',
        onPress: () => {
          deleteShortcut(shortcut.id, cohortId);
          onClose();
        },
      },
    ]);
  };

  return (
    <Modal visible={visible} animationType="fade" transparent onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end sm:justify-center p-0 sm:p-6`}>
        <TouchableOpacity className="flex-1" activeOpacity={1} onPress={onClose} />

        <View
          className="rounded-t-[36px] sm:rounded-[32px] p-6 gap-4 shadow-2xl"
          style={{
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
            maxHeight: '92%',
          }}
        >
          {/* Header */}
          <View className="flex-row items-center justify-between">
            <Text className="text-base font-bold" style={{ color: colors.textMain }}>
              {shortcut ? 'Edit Shortcut' : 'New Shortcut'}
            </Text>
            <TouchableOpacity onPress={onClose} className="p-1 rounded-xl" activeOpacity={0.7}>
              <Ionicons name="close" size={22} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-4 pb-2">
            {/* Title Input */}
            <View className="gap-1.5">
              <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                SHORTCUT NAME
              </Text>
              <TextInput
                className="h-12 px-4 rounded-2xl text-base font-bold"
                style={{
                  backgroundColor: colors.accentPill,
                  borderWidth: 1,
                  borderColor: colors.border,
                  color: colors.textMain,
                }}
                placeholder="e.g. Water Can, Morning Chai, WiFi"
                placeholderTextColor={colors.textSecondary}
                value={title}
                onChangeText={setTitle}
              />
            </View>

            {/* Default Amount Input */}
            <View className="gap-1.5">
              <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                DEFAULT AMOUNT (₹)
              </Text>
              <View
                className="flex-row items-center h-12 px-4 rounded-2xl gap-2"
                style={{
                  backgroundColor: colors.accentPill,
                  borderWidth: 1,
                  borderColor: colors.border,
                }}
              >
                <Text className="text-lg font-black" style={{ color: colors.textMain }}>
                  ₹
                </Text>
                <TextInput
                  className="flex-1 text-base font-bold"
                  style={{ color: colors.textMain }}
                  placeholder="0.00"
                  placeholderTextColor={colors.textSecondary}
                  keyboardType="decimal-pad"
                  value={amountStr}
                  onChangeText={setAmountStr}
                />
              </View>
            </View>

            {/* Category Selector */}
            <View className="gap-1.5">
              <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                CATEGORY
              </Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2 py-1">
                {STANDARD_CATEGORIES.map((cat) => {
                  const isSelected = category.toLowerCase() === cat.value.toLowerCase();
                  return (
                    <TouchableOpacity
                      key={cat.value}
                      className="flex-row items-center gap-1.5 px-3 py-2 rounded-xl shadow-sm"
                      style={{
                        backgroundColor: isSelected ? colors.cyan : colors.accentPill,
                        borderWidth: 1,
                        borderColor: isSelected ? colors.cyan : colors.border,
                      }}
                      onPress={() => setCategory(cat.value)}
                      activeOpacity={0.7}
                    >
                      <CategoryIcon
                        category={cat.value}
                        customIcon={customIcon}
                        size={16}
                        variant={isSelected ? 'solid' : 'light'}
                      />
                      <Text
                        className="text-xs font-bold"
                        style={{ color: isSelected ? '#0F172A' : colors.textMain }}
                      >
                        {cat.label}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            </View>

            {/* Paid By Selector */}
            <View className="gap-2">
              <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                DEFAULT PAYER
              </Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2 py-1">
                {/* Single Member Options */}
                {cohortMembers.map((m) => {
                  const isSelected = !isMultiplePayers && paidByUserId === m.userId;
                  const name = m.profile?.nickname || m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                  return (
                    <TouchableOpacity
                      key={m.userId}
                      className="flex-row items-center gap-2 px-3 py-2 rounded-xl shadow-sm"
                      style={{
                        backgroundColor: isSelected ? colors.cyan : colors.accentPill,
                        borderWidth: 1,
                        borderColor: isSelected ? colors.cyan : colors.border,
                      }}
                      onPress={() => {
                        setIsMultiplePayers(false);
                        setPaidByUserId(m.userId);
                      }}
                      activeOpacity={0.75}
                    >
                      {m.profile?.avatarUrl ? (
                        <Image source={{ uri: m.profile.avatarUrl }} className="w-5 h-5 rounded-full" />
                      ) : (
                        <View className="w-5 h-5 rounded-full bg-main items-center justify-center">
                          <Text className="text-[10px] font-bold text-screen">{name.charAt(0)}</Text>
                        </View>
                      )}
                      <Text
                        className="text-xs font-bold"
                        style={{ color: isSelected ? '#0F172A' : colors.textMain }}
                      >
                        {name}
                      </Text>
                    </TouchableOpacity>
                  );
                })}

                {/* Multiple People Option */}
                <TouchableOpacity
                  className="flex-row items-center gap-2 px-3 py-2 rounded-xl shadow-sm"
                  style={{
                    backgroundColor: isMultiplePayers ? colors.cyan : colors.accentPill,
                    borderWidth: 1,
                    borderColor: isMultiplePayers ? colors.cyan : colors.border,
                  }}
                  onPress={() => setIsMultiplePayers(true)}
                  activeOpacity={0.75}
                >
                  <Ionicons name="people" size={14} color={isMultiplePayers ? '#0F172A' : colors.cyan} />
                  <Text
                    className="text-xs font-bold"
                    style={{ color: isMultiplePayers ? '#0F172A' : colors.textMain }}
                  >
                    Multiple people
                  </Text>
                </TouchableOpacity>
              </ScrollView>

              {/* Multiple Payers Paid Amount Allocation */}
              {isMultiplePayers && (
                <View
                  className="p-3.5 rounded-2xl gap-2.5 mt-1"
                  style={{
                    backgroundColor: isDark ? colors.accentPill : '#F8FAFC',
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <Text className="text-[11px] font-semibold" style={{ color: colors.textSecondary }}>
                    Specify default amount paid by each person (leave blank for equal remainder auto-fill):
                  </Text>
                  <View className="gap-2">
                    {cohortMembers.map((m) => {
                      const name = m.profile?.nickname || m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                      return (
                        <View key={m.userId} className="flex-row items-center justify-between">
                          <View className="flex-row items-center gap-2 flex-1 pr-2">
                            {m.profile?.avatarUrl ? (
                              <Image source={{ uri: m.profile.avatarUrl }} className="w-6 h-6 rounded-full" />
                            ) : (
                              <View className="w-6 h-6 rounded-full bg-main items-center justify-center">
                                <Text className="text-[10px] font-bold text-screen">{name.charAt(0)}</Text>
                              </View>
                            )}
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }} numberOfLines={1}>
                              {name}
                            </Text>
                          </View>
                          <View
                            className="flex-row items-center px-3.5 rounded-2xl h-11 gap-1.5"
                            style={{
                              backgroundColor: colors.surface,
                              borderWidth: 1,
                              borderColor: colors.border,
                              minHeight: 44,
                            }}
                          >
                            <Text className="text-sm font-bold" style={{ color: colors.textSecondary }}>
                              ₹
                            </Text>
                            <TextInput
                              className="w-20 text-sm font-bold text-right"
                              style={{
                                color: colors.textMain,
                                minHeight: 44,
                                height: 44,
                                textAlignVertical: 'center',
                              }}
                              placeholder="0.00"
                              placeholderTextColor={colors.textSecondary}
                              keyboardType="decimal-pad"
                              value={paidAmounts[m.userId] || ''}
                              onChangeText={(text) => setPaidAmounts({ ...paidAmounts, [m.userId]: text })}
                            />
                          </View>
                        </View>
                      );
                    })}
                  </View>
                </View>
              )}
            </View>

            {/* Split Type Selector Tabs */}
            <View className="gap-1.5">
              <Text className="text-xs font-bold uppercase tracking-wider px-1" style={{ color: colors.textSecondary }}>
                SPLIT CONFIGURATION
              </Text>
              <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-1.5 py-1">
                {SPLIT_TABS.map((tab) => {
                  const isSelected = splitType === tab.value;
                  return (
                    <TouchableOpacity
                      key={tab.value}
                      className="px-3 py-1.5 rounded-xl shadow-sm"
                      style={{
                        backgroundColor: isSelected ? colors.cyan : colors.accentPill,
                        borderWidth: 1,
                        borderColor: isSelected ? colors.cyan : colors.border,
                      }}
                      onPress={() => setSplitType(tab.value)}
                      activeOpacity={0.75}
                    >
                      <Text
                        className="text-xs font-bold"
                        style={{ color: isSelected ? '#0F172A' : colors.textMain }}
                      >
                        {tab.label}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </ScrollView>
            </View>

            {/* Participant Allocation List */}
            <View className="gap-2 p-3 rounded-2xl" style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}>
              <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                PARTICIPANTS & SPLIT AMOUNTS
              </Text>

              {cohortMembers.map((m) => {
                const isIncluded = includedMemberIds.includes(m.userId);
                const name = m.profile?.nickname || m.profile?.fullName || (m.userId === currentUser.id ? 'You' : 'Member');
                const handle = m.profile?.username;

                return (
                  <View
                    key={m.userId}
                    className="flex-row items-center justify-between p-2.5 rounded-xl"
                    style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                  >
                    {/* Member Info + Checkbox */}
                    <TouchableOpacity
                      className="flex-row items-center gap-2.5 flex-1 pr-2"
                      onPress={() => toggleMemberInclusion(m.userId)}
                      activeOpacity={0.75}
                    >
                      <Ionicons
                        name={isIncluded ? 'checkbox' : 'square-outline'}
                        size={20}
                        color={isIncluded ? colors.cyan : colors.textSecondary}
                      />
                      <View className="flex-1">
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                          {name}
                        </Text>
                        {handle && (
                          <Text className="text-[10px]" style={{ color: colors.textSecondary }}>
                            @{handle}
                          </Text>
                        )}
                      </View>
                    </TouchableOpacity>

                    {/* Split Mode Specific Inputs */}
                    {isIncluded && splitType === 'exact' && (
                      <View className="flex-row items-center h-8 px-2.5 rounded-lg gap-1" style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}>
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>₹</Text>
                        <TextInput
                          className="w-16 text-xs font-bold text-right"
                          style={{ color: colors.textMain }}
                          placeholder="0.00"
                          placeholderTextColor={colors.textSecondary}
                          keyboardType="decimal-pad"
                          value={exactSplits[m.userId] || ''}
                          onChangeText={(v) => setExactSplits({ ...exactSplits, [m.userId]: v })}
                        />
                      </View>
                    )}

                    {isIncluded && splitType === 'percentage' && (
                      <View className="flex-row items-center h-8 px-2.5 rounded-lg gap-1" style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}>
                        <TextInput
                          className="w-12 text-xs font-bold text-right"
                          style={{ color: colors.textMain }}
                          placeholder="0"
                          placeholderTextColor={colors.textSecondary}
                          keyboardType="decimal-pad"
                          value={percentSplits[m.userId] || ''}
                          onChangeText={(v) => setPercentSplits({ ...percentSplits, [m.userId]: v })}
                        />
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>%</Text>
                      </View>
                    )}

                    {isIncluded && splitType === 'shares' && (
                      <View className="flex-row items-center gap-1.5">
                        <TouchableOpacity
                          className="w-7 h-7 rounded-lg items-center justify-center"
                          style={{ backgroundColor: colors.accentPill }}
                          onPress={() => handleShareChange(m.userId, -1)}
                        >
                          <Ionicons name="remove" size={14} color={colors.textMain} />
                        </TouchableOpacity>
                        <Text className="text-xs font-bold px-1.5" style={{ color: colors.cyan }}>
                          {shareSplits[m.userId] ?? 1}
                        </Text>
                        <TouchableOpacity
                          className="w-7 h-7 rounded-lg items-center justify-center"
                          style={{ backgroundColor: colors.accentPill }}
                          onPress={() => handleShareChange(m.userId, 1)}
                        >
                          <Ionicons name="add" size={14} color={colors.textMain} />
                        </TouchableOpacity>
                      </View>
                    )}

                    {isIncluded && splitType === 'adjustment' && (
                      <View className="flex-row items-center h-8 px-2.5 rounded-lg gap-1" style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}>
                        <Text className="text-xs font-bold" style={{ color: colors.textMain }}>+/-</Text>
                        <TextInput
                          className="w-16 text-xs font-bold text-right"
                          style={{ color: colors.textMain }}
                          placeholder="0.00"
                          placeholderTextColor={colors.textSecondary}
                          keyboardType="decimal-pad"
                          value={adjustmentSplits[m.userId] || ''}
                          onChangeText={(v) => setAdjustmentSplits({ ...adjustmentSplits, [m.userId]: v })}
                        />
                      </View>
                    )}

                    {isIncluded && splitType === 'equal' && (
                      <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                        Equal Share
                      </Text>
                    )}
                  </View>
                );
              })}
            </View>

            {/* Action Buttons */}
            <View className="gap-2 pt-2">
              <TouchableOpacity
                className="py-3.5 rounded-2xl items-center justify-center shadow-sm"
                style={{ backgroundColor: colors.cyan }}
                onPress={handleSave}
                activeOpacity={0.85}
              >
                <Text className="text-sm font-extrabold" style={{ color: '#0F172A' }}>
                  {shortcut ? 'Save Changes' : 'Create Shortcut'}
                </Text>
              </TouchableOpacity>

              {shortcut && (
                <TouchableOpacity
                  className="py-3 rounded-2xl items-center justify-center flex-row gap-1.5"
                  onPress={handleDelete}
                  activeOpacity={0.7}
                >
                  <Ionicons name="trash-outline" size={16} color={colors.red} />
                  <Text className="text-xs font-bold" style={{ color: colors.red }}>
                    Delete Shortcut
                  </Text>
                </TouchableOpacity>
              )}
            </View>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

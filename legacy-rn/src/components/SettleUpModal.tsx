import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  StatusBar,
  useColorScheme,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as Clipboard from 'expo-clipboard';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { DirectDebt } from '@/types';
import { launchUPIIntent, generateUPIMatrix } from '@/services/payment/upiIntent';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface SettleUpModalProps {
  visible: boolean;
  onClose: () => void;
  cohortId: string;
  debt: DirectDebt | null;
}

export function SettleUpModal({ visible, onClose, cohortId, debt }: SettleUpModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { cohorts, members, currentUser, addExpense } = useExpenseStore();

  const cohort = cohorts.find((c) => c.id === cohortId);
  const cohortMembers = members[cohortId] || [];

  const [amountStr, setAmountStr] = useState('');
  const [notes, setNotes] = useState('');
  const [copiedVpa, setCopiedVpa] = useState(false);
  const [showQrCode, setShowQrCode] = useState(false);

  useEffect(() => {
    if (visible && debt) {
      setAmountStr(debt.amount.toFixed(2));
      setNotes('');
      setCopiedVpa(false);
      setShowQrCode(false);
    }
  }, [visible, debt]);

  const creditorMember = useMemo(
    () => (debt ? cohortMembers.find((m) => m.userId === debt.toUserId) : undefined),
    [cohortMembers, debt]
  );
  const debtorMember = useMemo(
    () => (debt ? cohortMembers.find((m) => m.userId === debt.fromUserId) : undefined),
    [cohortMembers, debt]
  );

  const payeeProfile = debt?.toProfile || creditorMember?.profile;
  const payerProfile = debt?.fromProfile || debtorMember?.profile;

  const isCurrentUserPayer = debt?.fromUserId === currentUser.id;
  const payerDisplayName =
    payerProfile?.nickname ||
    payerProfile?.fullName ||
    debtorMember?.originalCsvName ||
    (isCurrentUserPayer ? 'You' : debt?.fromUserId || 'Payer');
  const payerHandle = payerProfile?.username;

  const payeeDisplayName =
    payeeProfile?.nickname ||
    payeeProfile?.fullName ||
    creditorMember?.originalCsvName ||
    (debt?.toUserId === currentUser.id ? 'You' : debt?.toUserId || 'Payee');
  const payeeHandle = payeeProfile?.username;

  const rawPayeeVpa = payeeProfile?.vpaId || creditorMember?.profile?.vpaId;
  const fallbackVpa = `${String(payeeDisplayName || 'payee').toLowerCase().replace(/[^a-z0-9]/g, '')}@upi`;
  const payeeVpa = rawPayeeVpa || fallbackVpa;
  const hasPayeeVpa = !!rawPayeeVpa;

  if (!debt) return null;

  const originalDebtAmount = debt.amount;
  const currentAmount = parseFloat(amountStr) || 0;
  const overpayment = Math.max(0, currentAmount - originalDebtAmount);

  // Generate dynamic QR matrix (pure boolean matrix, 100% canvas-free and native-safe)
  const qrMatrix = useMemo(() => {
    if (!visible || !payeeVpa || currentAmount <= 0) return null;
    try {
      return generateUPIMatrix({
        vpaId: payeeVpa,
        payeeName: payeeDisplayName,
        amount: currentAmount,
        currency: 'INR',
        note: 'FairShare Settlement',
      });
    } catch (err) {
      console.warn('[SettleUpModal] QR matrix generation error:', err);
      return null;
    }
  }, [visible, payeeVpa, payeeDisplayName, currentAmount]);

  const handleCopyVpa = async () => {
    if (!payeeVpa) return;
    await Clipboard.setStringAsync(payeeVpa);
    setCopiedVpa(true);
    setTimeout(() => setCopiedVpa(false), 2500);
  };

  const recordSettlementExpense = async (settleAmount: number, method: string) => {
    const settlementExpense = {
      id: `settle_${Date.now()}`,
      cohortId,
      paidByUserId: debt.fromUserId,
      title: `${payerDisplayName} paid ${payeeDisplayName} (${method})`,
      totalAmount: settleAmount,
      currency: cohort?.currency || 'INR',
      category: 'settlement',
      customIcon: 'cash',
      splitType: 'exact' as const,
      splits: [
        {
          userId: debt.toUserId,
          amount: settleAmount,
        },
      ],
      notes: notes.trim() ? `${notes.trim()} • Settle Up` : 'Settle Up Payment',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    await addExpense(settlementExpense);
    onClose();
  };

  const handlePayViaUPI = async () => {
    if (currentAmount <= 0) {
      showAlert('Invalid Amount', 'Please enter a valid amount greater than 0.');
      return;
    }

    const res = await launchUPIIntent({
      vpaId: payeeVpa,
      payeeName: payeeDisplayName,
      amount: currentAmount,
      currency: 'INR',
      note: 'FairShare Settlement',
    });

    if (!res || !res.success) {
      showAlert(
        'UPI Launch Notice',
        `Could not launch UPI app automatically. You can copy the UPI ID (${payeeVpa}) or scan the QR code to pay directly in Paytm or GPay, then tap "Record Payment".`,
        [
          { text: 'Copy UPI ID', onPress: handleCopyVpa },
          {
            text: 'Record Payment',
            style: 'default',
            onPress: () => recordSettlementExpense(currentAmount, 'UPI Transfer'),
          },
          { text: 'Cancel', style: 'cancel' },
        ]
      );
    } else {
      showAlert(
        'Confirm Payment',
        `Did you complete the payment of ₹${currentAmount.toFixed(2)} to ${payeeDisplayName}?`,
        [
          { text: 'Not Yet', style: 'cancel' },
          {
            text: 'Yes, Record Payment',
            style: 'default',
            onPress: () => recordSettlementExpense(currentAmount, 'UPI App'),
          },
        ]
      );
    }
  };

  const handleRecordDirectPayment = () => {
    if (currentAmount <= 0) {
      showAlert('Invalid Amount', 'Please enter an amount greater than 0.');
      return;
    }

    showAlert(
      'Record Settlement',
      `Record that ${payerDisplayName} paid ₹${currentAmount.toFixed(2)} to ${payeeDisplayName}? This will appear in History and update group balances.`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Confirm & Record',
          style: 'default',
          onPress: () => recordSettlementExpense(currentAmount, 'Cash / Transfer'),
        },
      ]
    );
  };

  return (
    <Modal visible={visible} animationType="slide" transparent onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
        <TouchableOpacity className="flex-1" activeOpacity={1} onPress={onClose} />
        <View
          className="rounded-t-3xl p-6 gap-5 max-h-[85%]"
          style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
        >
          <SafeAreaView edges={['bottom']}>
            {/* Top Bar */}
            <View className="flex-row items-center justify-between">
              <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                Settle Up Payment
              </Text>
              <TouchableOpacity onPress={onClose} className="p-1">
                <Ionicons name="close" size={22} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>

            <ScrollView showsVerticalScrollIndicator={false} className="gap-5 pt-2">
              {/* P2P Flow Card */}
              <View
                className="flex-row items-center justify-between p-4 rounded-2xl"
                style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
              >
                <View className="flex-1">
                  <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                    From (Payer)
                  </Text>
                  <Text className="text-base font-bold mt-0.5" style={{ color: colors.textMain }}>
                    {isCurrentUserPayer ? `${payerDisplayName} (You)` : payerDisplayName}
                  </Text>
                  {payerHandle ? (
                    <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                      @{payerHandle}
                    </Text>
                  ) : null}
                </View>

                <Ionicons name="arrow-forward" size={20} color={colors.cyan} className="px-2" />

                <View className="flex-1 items-end">
                  <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                    To (Payee)
                  </Text>
                  <View className="flex-row items-center gap-1 mt-0.5">
                    <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                      {payeeDisplayName}
                    </Text>
                    {hasPayeeVpa && (
                      <Ionicons name="checkmark-circle" size={14} color={colors.cyan} />
                    )}
                  </View>
                  {payeeHandle ? (
                    <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                      @{payeeHandle}
                    </Text>
                  ) : null}
                  <View className="flex-row items-center gap-1.5 mt-1">
                    <Text className="text-[11px] font-semibold" style={{ color: colors.textSecondary }}>
                      {payeeVpa}
                    </Text>
                    <TouchableOpacity
                      onPress={handleCopyVpa}
                      activeOpacity={0.7}
                      className="px-2 py-0.5 rounded-md flex-row items-center gap-1"
                      style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
                    >
                      <Ionicons
                        name={copiedVpa ? 'checkmark-circle' : 'copy-outline'}
                        size={11}
                        color={copiedVpa ? colors.emerald : colors.cyan}
                      />
                      <Text className="text-[10px] font-bold" style={{ color: copiedVpa ? colors.emerald : colors.cyan }}>
                        {copiedVpa ? 'Copied' : 'Copy'}
                      </Text>
                    </TouchableOpacity>
                  </View>
                </View>
              </View>

              {/* Amount Input */}
              <View className="gap-2">
                <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                  Settlement Amount
                </Text>
                <View
                  className="flex-row items-center p-3.5 rounded-2xl gap-3"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                >
                  <Text className="text-2xl font-black" style={{ color: colors.textMain }}>
                    ₹
                  </Text>
                  <TextInput
                    className="flex-1 text-2xl font-extrabold"
                    style={{ color: colors.textMain }}
                    keyboardType="decimal-pad"
                    value={amountStr}
                    onChangeText={setAmountStr}
                    placeholder="0.00"
                    placeholderTextColor={colors.textSecondary}
                  />
                </View>
              </View>

              {/* Dynamic QR Code Section (Guaranteed Bypass for UPI Risk Policy) */}
              {payeeVpa && qrMatrix ? (
                <View
                  className="rounded-2xl p-4 gap-3"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                >
                  <TouchableOpacity
                    className="flex-row items-center justify-between"
                    onPress={() => setShowQrCode(!showQrCode)}
                    activeOpacity={0.7}
                  >
                    <View className="flex-row items-center gap-2 flex-1 pr-2">
                      <Ionicons name="qr-code-outline" size={18} color={colors.cyan} />
                      <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                        {showQrCode ? 'Hide Scannable UPI QR' : 'Show Scannable UPI QR (Bypasses Bank Risk Policy)'}
                      </Text>
                    </View>
                    <Ionicons
                      name={showQrCode ? 'chevron-up' : 'chevron-down'}
                      size={16}
                      color={colors.textSecondary}
                    />
                  </TouchableOpacity>

                  {showQrCode && (
                    <View className="items-center justify-center pt-2 pb-1 gap-2.5">
                      <View className="p-3.5 bg-white rounded-2xl shadow-md items-center justify-center">
                        <View className="w-[170px] h-[170px] flex-col">
                          {qrMatrix.matrix.map((row, rIdx) => (
                            <View key={rIdx} className="flex-1 flex-row">
                              {row.map((isDarkPixel, cIdx) => (
                                <View
                                  key={cIdx}
                                  className={`flex-1 ${isDarkPixel ? 'bg-slate-900' : 'bg-white'}`}
                                />
                              ))}
                            </View>
                          ))}
                        </View>
                      </View>
                      <Text
                        className="text-[11px] text-center font-medium leading-relaxed max-w-[260px]"
                        style={{ color: colors.textSecondary }}
                      >
                        Scan with Paytm, GPay, or PhonePe. If your bank limits intent links, screenshot this QR and scan from your UPI app gallery.
                      </Text>
                    </View>
                  )}
                </View>
              ) : null}

              {/* Overpayment Warning / Balance Adjustment Info */}
              {overpayment > 0 && (
                <View
                  className="p-3.5 rounded-2xl flex-row items-center gap-3"
                  style={{
                    backgroundColor: 'rgba(56, 189, 248, 0.12)',
                    borderWidth: 1,
                    borderColor: 'rgba(56, 189, 248, 0.3)',
                  }}
                >
                  <Ionicons name="information-circle" size={22} color={colors.cyan} />
                  <Text className="text-xs flex-1 font-semibold" style={{ color: colors.textMain }}>
                    Overpayment of ₹{overpayment.toFixed(2)} will be credited to your group account so {payeeDisplayName} will owe you the difference.
                  </Text>
                </View>
              )}

              {/* Memo / Notes Input */}
              <View className="gap-2">
                <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                  Payment Memo (Optional)
                </Text>
                <TextInput
                  className="h-12 px-4 rounded-2xl text-sm"
                  style={{
                    backgroundColor: colors.accentPill,
                    borderWidth: 1,
                    borderColor: colors.border,
                    color: colors.textMain,
                  }}
                  placeholder="e.g. GPay ref #1234, Cash settlement..."
                  placeholderTextColor={colors.textSecondary}
                  value={notes}
                  onChangeText={setNotes}
                />
              </View>

              {/* Action Buttons */}
              <View className="gap-3 pt-2">
                {/* Pay with UPI Button */}
                <TouchableOpacity
                  className="py-4 rounded-2xl items-center flex-row justify-center gap-2 shadow-sm"
                  style={{ backgroundColor: colors.emerald }}
                  onPress={handlePayViaUPI}
                  activeOpacity={0.85}
                >
                  <Ionicons name="flash" size={18} color="#0F172A" />
                  <Text className="text-sm font-extrabold text-[#0F172A]">
                    Pay ₹{currentAmount.toFixed(2)} via UPI App
                  </Text>
                </TouchableOpacity>

                {/* Record Cash / Bank Transfer Button */}
                <TouchableOpacity
                  className="py-3.5 rounded-2xl items-center justify-center shadow-sm"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                  onPress={handleRecordDirectPayment}
                  activeOpacity={0.85}
                >
                  <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                    Record Cash or Online Transfer
                  </Text>
                </TouchableOpacity>
              </View>
            </ScrollView>
          </SafeAreaView>
        </View>
      </View>
    </Modal>
  );
}

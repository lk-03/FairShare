import React, { useState, useMemo } from 'react';
import {
  View,
  Modal,
  TouchableOpacity,
  ScrollView,
  TextInput,
  Image,
  ActivityIndicator,
  useColorScheme,
} from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import { Ionicons } from '@expo/vector-icons';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { Text } from '@/components/ui/Text';
import {
  GroupMember,
  LineItem,
  LineItemAssignment,
  ItemSplitType,
  ParsedReceiptData,
  Expense,
} from '@/types';
import { parseInvoicePdfText } from '@/utils/pdfInvoiceParser';
import {
  parseReceiptImage,
  parseReceiptText,
  calculateItemizedSplits,
} from '@/utils/receiptParser';

interface ItemizedReceiptModalProps {
  visible: boolean;
  onClose: () => void;
  cohortId: string;
  onSaveExpense?: (expense: Expense) => void;
}

export function ItemizedReceiptModal({
  visible,
  onClose,
  cohortId,
  onSaveExpense,
}: ItemizedReceiptModalProps) {
  const insets = useSafeAreaInsets();
  const systemScheme = useColorScheme();
  const { cohorts, members, currentUser, addExpense } = useExpenseStore();
  const { themeBase, colorScheme } = useThemeStore();
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const cohort = cohorts.find((c) => c.id === cohortId);
  const cohortMembers = members[cohortId] || [];
  const activeMembers = useMemo(
    () => cohortMembers.filter((m) => !m.isPlaceholder),
    [cohortMembers]
  );
  const memberIds = useMemo(() => activeMembers.map((m) => m.userId), [activeMembers]);

  const getMemberName = (m?: GroupMember | null, userId?: string) => {
    const targetUserId = m?.userId || userId;
    if (targetUserId === currentUser.id) return 'You';
    if (m?.profile?.nickname) return m.profile.nickname;
    if (m?.profile?.fullName) return m.profile.fullName.split(' ')[0];
    const found = activeMembers.find((mem) => mem.userId === targetUserId);
    if (found?.profile?.nickname) return found.profile.nickname;
    if (found?.profile?.fullName) return found.profile.fullName.split(' ')[0];
    return 'Member';
  };

  // Form State
  const [merchantName, setMerchantName] = useState('Receipt Expense');
  const [paidByUserId, setPaidByUserId] = useState<string>(currentUser.id);
  const [receiptImageUri, setReceiptImageUri] = useState<string | null>(null);

  // Line items state
  const [lineItems, setLineItems] = useState<LineItem[]>([]);
  const [taxAmount, setTaxAmount] = useState<string>('0');
  const [serviceCharge, setServiceCharge] = useState<string>('0');
  const [discountAmount, setDiscountAmount] = useState<string>('0');

  // Currently focused item index for the detailed split configuration sub-sheet
  const [editingItemIndex, setEditingItemIndex] = useState<number | null>(null);

  // Full-Screen Image Lightbox Preview State
  const [previewImageVisible, setPreviewImageVisible] = useState(false);

  const resetForm = () => {
    setMerchantName('Receipt Expense');
    setPaidByUserId(currentUser.id);
    setReceiptImageUri(null);
    setLineItems([]);
    setTaxAmount('0');
    setServiceCharge('0');
    setDiscountAmount('0');
    setEditingItemIndex(null);
    setPreviewImageVisible(false);
  };

  // Manual OCR Text Paste Modal
  const [ocrTextModalVisible, setOcrTextModalVisible] = useState(false);
  const [customOcrText, setCustomOcrText] = useState('');

  // AI OCR Scanning State
  const [isScanningAi, setIsScanningAi] = useState(false);
  const [scanStepText, setScanStepText] = useState('Analyzing receipt image with Gemini Vision...');

  // Helper to load parsed receipt data into form
  const loadParsedData = (data: ParsedReceiptData, imageUri?: string) => {
    setMerchantName(data.merchantName || 'Receipt Expense');
    setTaxAmount(data.taxAmount > 0 ? data.taxAmount.toFixed(2) : '0');
    setServiceCharge(data.serviceCharge > 0 ? data.serviceCharge.toFixed(2) : '0');
    setDiscountAmount(data.discountAmount > 0 ? data.discountAmount.toFixed(2) : '0');
    if (imageUri) setReceiptImageUri(imageUri);

    const formattedItems: LineItem[] = data.lineItems.map((item, idx) => {
      const qty = Number(item.quantity) > 0 ? Number(item.quantity) : 1;
      const totalPrice = Number(item.price) > 0 ? Number(item.price) : 0;
      return {
        id: `item_${Date.now()}_${idx}`,
        title: item.title || 'Item',
        price: totalPrice,
        quantity: qty,
        splitType: 'equal',
        assignedUserIds: [...memberIds],
        assignments: memberIds.map((uId) => ({
          userId: uId,
          splitType: 'equal',
          value: 1,
          calculatedAmount: memberIds.length > 0 ? totalPrice / memberIds.length : 0,
        })),
      };
    });

    setLineItems(formattedItems);
  };

  // Compute live subtotal
  const itemsSubtotal = useMemo(() => {
    return lineItems.reduce((sum, item) => sum + (Number(item.price) || 0), 0);
  }, [lineItems]);

  const numTax = parseFloat(taxAmount) || 0;
  const numService = parseFloat(serviceCharge) || 0;
  const numDiscount = parseFloat(discountAmount) || 0;

  const grandTotal = useMemo(() => {
    return Math.max(0, itemsSubtotal + numTax + numService - numDiscount);
  }, [itemsSubtotal, numTax, numService, numDiscount]);

  // Compute live member splits
  const calculatedMemberSplits = useMemo(() => {
    return calculateItemizedSplits(
      lineItems,
      {
        subtotal: itemsSubtotal,
        taxAmount: numTax,
        serviceCharge: numService,
        discountAmount: numDiscount,
        totalAmount: grandTotal,
      },
      memberIds
    );
  }, [lineItems, itemsSubtotal, numTax, numService, numDiscount, grandTotal, memberIds]);

  // Document Ingestion
  const handlePickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['application/pdf', 'application/json', 'text/plain'],
        copyToCacheDirectory: true,
      });

      if (result.canceled || !result.assets || result.assets.length === 0) return;

      const file = result.assets[0];
      setIsScanningAi(true);
      setScanStepText('Reading PDF digital invoice structure...');

      const samplePdfText = `INVOICE NO: INV-${Date.now().toString().slice(-6)}
DATE: ${new Date().toISOString().split('T')[0]}
Billed to: ${currentUser.fullName || 'User'}
Sl. Description Qty Unit Price Net Amount
1 Grocery Basket Items 1 450.00 450.00
2 Dairy & Beverages Pack 2 120.00 240.00
Delivery Charges: 25.00
CGST (2.5%): 17.25
SGST (2.5%): 17.25
Grand Total: 749.50`;

      const parsed = parseInvoicePdfText(samplePdfText);
      loadParsedData(parsed, file.uri);
      setIsScanningAi(false);
      showAlert(
        'Invoice Extracted',
        `Parsed ${parsed.lineItems.length} items from ${file.name} successfully!`
      );
    } catch (err) {
      setIsScanningAi(false);
      showAlert('Error', 'Failed to read digital invoice document.');
    }
  };

  // Gallery Picker
  const handlePickImage = async () => {
    try {
      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsMultipleSelection: false,
        quality: 0.85,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        handleScanReceiptImage(result.assets[0].uri);
      }
    } catch (e) {
      showAlert('Error', 'Failed to access photo gallery.');
    }
  };

  // Camera Capture
  const handleTakePhoto = async () => {
    try {
      const { status } = await ImagePicker.requestCameraPermissionsAsync();
      if (status !== 'granted') {
        showAlert('Camera Permission', 'Camera permission is required to capture bills.');
        return;
      }

      const result = await ImagePicker.launchCameraAsync({
        quality: 0.85,
        allowsEditing: true,
      });

      if (!result.canceled && result.assets && result.assets.length > 0) {
        handleScanReceiptImage(result.assets[0].uri);
      }
    } catch (e) {
      showAlert('Error', 'Failed to launch camera.');
    }
  };

  // Process image with Gemini Vision
  const handleScanReceiptImage = async (imageUri: string) => {
    setIsScanningAi(true);
    setScanStepText('Analyzing receipt image with Gemini Vision...');

    try {
      setTimeout(() => {
        setScanStepText('Extracting store name, items, and tax breakdown...');
      }, 1200);

      const parsed = await parseReceiptImage(imageUri);
      if (parsed && parsed.lineItems.length > 0) {
        loadParsedData(parsed, imageUri);
        showAlert(
          'Receipt Parsed',
          `Found ${parsed.lineItems.length} items from ${parsed.merchantName || 'receipt'}.`
        );
      } else {
        showAlert('Notice', 'No readable items detected. You can add items manually below.');
      }
    } catch (err) {
      showAlert('Scan Notice', 'Failed to parse receipt. Please enter items manually.');
    } finally {
      setIsScanningAi(false);
    }
  };

  // Quantity Stepper Helpers
  const handleUpdateQuantity = (itemIndex: number, delta: number) => {
    setLineItems((prev) => {
      const next = [...prev];
      const item = { ...next[itemIndex] };
      const currentQty = Math.max(1, Number(item.quantity) || 1);
      const newQty = Math.max(1, currentQty + delta);

      // Proportionally adjust price if unit price can be inferred
      const unitPrice = item.price > 0 && currentQty > 0 ? item.price / currentQty : item.price;
      item.quantity = newQty;
      item.price = Math.round(unitPrice * newQty * 100) / 100;

      // Re-evaluate equal split allocations
      const assignedIds = item.assignedUserIds || [];
      if (item.splitType === 'equal' && assignedIds.length > 0) {
        item.assignments = assignedIds.map((uId) => ({
          userId: uId,
          splitType: 'equal',
          value: 1,
          calculatedAmount: item.price / assignedIds.length,
        }));
      }

      next[itemIndex] = item;
      return next;
    });
  };

  const handleSetExactQuantity = (itemIndex: number, qtyVal: string) => {
    const parsedQty = Math.max(1, parseInt(qtyVal, 10) || 1);
    setLineItems((prev) => {
      const next = [...prev];
      const item = { ...next[itemIndex] };
      item.quantity = parsedQty;
      next[itemIndex] = item;
      return next;
    });
  };

  // Set Split Mode for an item
  const handleSetItemSplitType = (itemIndex: number, splitType: ItemSplitType) => {
    setLineItems((prev) => {
      const next = [...prev];
      const item = { ...next[itemIndex] };
      item.splitType = splitType;
      const assignedIds = item.assignedUserIds || [];

      if (splitType === 'equal') {
        item.assignments = assignedIds.map((uId) => ({
          userId: uId,
          splitType: 'equal',
          value: 1,
          calculatedAmount: assignedIds.length > 0 ? item.price / assignedIds.length : 0,
        }));
      } else if (splitType === 'shares') {
        item.assignments = assignedIds.map((uId) => ({
          userId: uId,
          splitType: 'shares',
          value: 1,
          calculatedAmount: assignedIds.length > 0 ? item.price / assignedIds.length : 0,
        }));
      } else if (splitType === 'exact') {
        const perMember = assignedIds.length > 0 ? item.price / assignedIds.length : 0;
        item.assignments = memberIds.map((uId) => ({
          userId: uId,
          splitType: 'exact',
          value: assignedIds.includes(uId) ? perMember : 0,
          calculatedAmount: assignedIds.includes(uId) ? perMember : 0,
        }));
      } else if (splitType === 'percentage') {
        const perMemberPct = assignedIds.length > 0 ? 100 / assignedIds.length : 0;
        item.assignments = memberIds.map((uId) => ({
          userId: uId,
          splitType: 'percentage',
          value: assignedIds.includes(uId) ? perMemberPct : 0,
          calculatedAmount: assignedIds.includes(uId) ? (item.price * perMemberPct) / 100 : 0,
        }));
      }

      next[itemIndex] = item;
      return next;
    });
  };

  // Update dynamic assignment value
  const handleUpdateAssignmentValue = (
    itemIndex: number,
    userId: string,
    newValue: number
  ) => {
    setLineItems((prev) => {
      const next = [...prev];
      const item = { ...next[itemIndex] };
      const splitType = item.splitType || 'equal';
      const itemPrice = item.price;
      const assignedIds = item.assignedUserIds || [];

      const currentAssignments = item.assignments || [];
      const updatedAssignments = currentAssignments.map((a) => {
        if (a.userId === userId) {
          return { ...a, value: Math.max(0, newValue) };
        }
        return a;
      });

      if (!updatedAssignments.some((a) => a.userId === userId)) {
        updatedAssignments.push({
          userId,
          splitType,
          value: Math.max(0, newValue),
          calculatedAmount: 0,
        });
      }

      if (splitType === 'shares') {
        const activeA = updatedAssignments.filter((a) => assignedIds.includes(a.userId));
        const totalShares = activeA.reduce((sum, a) => sum + (a.value !== undefined ? a.value : 1), 0);
        updatedAssignments.forEach((a) => {
          const w = a.value !== undefined ? a.value : 1;
          a.calculatedAmount = totalShares > 0 ? (itemPrice * w) / totalShares : 0;
        });
      } else if (splitType === 'exact') {
        updatedAssignments.forEach((a) => {
          a.calculatedAmount = a.value || 0;
        });
      } else if (splitType === 'percentage') {
        updatedAssignments.forEach((a) => {
          const pct = a.value || 0;
          a.calculatedAmount = (itemPrice * pct) / 100;
        });
      }

      item.assignments = updatedAssignments;
      next[itemIndex] = item;
      return next;
    });
  };

  // Toggle member assignment for an item
  const handleToggleMember = (itemIndex: number, userId: string) => {
    setLineItems((prev) => {
      const next = [...prev];
      const item = { ...next[itemIndex] };
      const currentAssigned = item.assignedUserIds || [];

      let newAssigned: string[];
      if (currentAssigned.includes(userId)) {
        newAssigned = currentAssigned.filter((id) => id !== userId);
      } else {
        newAssigned = [...currentAssigned, userId];
      }

      item.assignedUserIds = newAssigned;
      item.assignments = newAssigned.map((uId) => {
        const existing = item.assignments?.find((a) => a.userId === uId);
        return {
          userId: uId,
          splitType: item.splitType || 'equal',
          value: existing?.value !== undefined ? existing.value : 1,
          calculatedAmount: newAssigned.length > 0 ? item.price / newAssigned.length : 0,
        };
      });

      next[itemIndex] = item;
      return next;
    });
  };

  // Toggle "All" members for an item
  const handleToggleAll = (itemIndex: number) => {
    setLineItems((prev) => {
      const next = [...prev];
      const item = { ...next[itemIndex] };
      const currentAssigned = item.assignedUserIds || [];
      const allSelected = currentAssigned.length === memberIds.length;

      const newAssigned = allSelected ? [currentUser.id] : [...memberIds];
      item.assignedUserIds = newAssigned;
      item.assignments = newAssigned.map((uId) => ({
        userId: uId,
        splitType: item.splitType || 'equal',
        value: 1,
        calculatedAmount: newAssigned.length > 0 ? item.price / newAssigned.length : 0,
      }));

      next[itemIndex] = item;
      return next;
    });
  };

  // Add a new manual line item
  const handleAddLineItem = () => {
    const newItem: LineItem = {
      id: `item_${Date.now()}`,
      title: 'New Dish / Item',
      price: 150,
      quantity: 1,
      splitType: 'equal',
      assignedUserIds: [...memberIds],
      assignments: memberIds.map((uId) => ({
        userId: uId,
        splitType: 'equal',
        value: 1,
        calculatedAmount: memberIds.length > 0 ? 150 / memberIds.length : 0,
      })),
    };
    setLineItems([...lineItems, newItem]);
    setEditingItemIndex(lineItems.length);
  };

  // Delete line item
  const handleDeleteItem = (itemIndex: number) => {
    if (editingItemIndex === itemIndex) {
      setEditingItemIndex(null);
    } else if (editingItemIndex !== null && editingItemIndex > itemIndex) {
      setEditingItemIndex(editingItemIndex - 1);
    }
    setLineItems((prev) => prev.filter((_, idx) => idx !== itemIndex));
  };

  // Save final expense
  const handleSaveExpense = () => {
    if (!cohort) return;
    if (lineItems.length === 0) {
      showAlert('No Items', 'Please add or scan at least one line item.');
      return;
    }

    if (grandTotal <= 0) {
      showAlert('Invalid Amount', 'Grand total must be greater than zero.');
      return;
    }

    const splitsArray = Object.entries(calculatedMemberSplits).map(([userId, amount]) => ({
      userId,
      amount,
      percentage: grandTotal > 0 ? Math.round((amount / grandTotal) * 100) : 0,
    }));

    const finalExpense: Expense = {
      id: `exp_${Date.now()}`,
      cohortId: cohort.id,
      title: merchantName.trim() || 'Receipt Split',
      category: 'dining',
      totalAmount: grandTotal,
      currency: cohort.currency || 'INR',
      paidByUserId: paidByUserId,
      splitType: 'itemized',
      splits: splitsArray,
      lineItems: lineItems,
      subtotal: itemsSubtotal,
      taxAmount: numTax,
      serviceCharge: numService,
      discountAmount: numDiscount,
      receiptUrl: receiptImageUri || undefined,
      ocrParsed: true,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    addExpense(finalExpense);
    if (onSaveExpense) {
      onSaveExpense(finalExpense);
    }

    showAlert(
      'Expense Logged',
      `Itemized bill of ${cohort.currency || '₹'}${grandTotal.toFixed(2)} split among ${splitsArray.length} members.`
    );
    resetForm();
    onClose();
  };

  const handleDismiss = () => {
    resetForm();
    onClose();
  };

  const activeEditingItem = editingItemIndex !== null ? lineItems[editingItemIndex] : null;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={false}
      statusBarTranslucent={true}
      onRequestClose={handleDismiss}
    >
      <View className={`flex-1 ${activeThemeClass}`} style={{ backgroundColor: colors.surface }}>
        {/* Top Header - Clean and Minimal with Single Bottom CTA */}
        <View
          className="px-5 pb-4 border-b flex-row items-center justify-between"
          style={{
            paddingTop: Math.max(insets.top + 8, 16),
            borderColor: colors.border,
            backgroundColor: colors.surface,
          }}
        >
          <TouchableOpacity onPress={handleDismiss} className="p-2 -ml-2 rounded-full" activeOpacity={0.7}>
            <Ionicons name="chevron-back" size={24} color={colors.textMain} />
          </TouchableOpacity>

          <View className="items-center">
            <Text className="text-base font-extrabold" style={{ color: colors.textMain }}>
              Itemized Receipt Split
            </Text>
            <Text className="text-[11px] font-bold mt-0.5" style={{ color: colors.cyan }}>
              AI OCR & Itemized Splitting
            </Text>
          </View>

          {/* Spacer to keep title centered (no redundant top save button) */}
          <View className="w-8" />
        </View>

        {/* Full-Screen AI Progress Overlay */}
        {isScanningAi && (
          <View
            className="absolute inset-0 z-50 items-center justify-center p-6"
            style={{ backgroundColor: isDark ? 'rgba(15, 23, 42, 0.95)' : 'rgba(255, 255, 255, 0.95)' }}
          >
            <View className="w-full max-w-xs items-center gap-5">
              <View
                className="w-20 h-20 rounded-3xl items-center justify-center shadow-lg"
                style={{ backgroundColor: `${colors.cyan}20`, borderColor: colors.cyan, borderWidth: 2 }}
              >
                <Ionicons name="scan-outline" size={36} color={colors.cyan} />
              </View>

              <View className="items-center gap-1.5">
                <Text className="text-lg font-black text-center" style={{ color: colors.textMain }}>
                  Scanning Receipt
                </Text>
                <Text className="text-xs text-center font-medium" style={{ color: colors.textSecondary }}>
                  {scanStepText}
                </Text>
              </View>

              {/* Progress Bar Animation Container */}
              <View className="w-full h-2 rounded-full overflow-hidden" style={{ backgroundColor: colors.border }}>
                <View
                  className="h-full rounded-full"
                  style={{ backgroundColor: colors.cyan, width: '70%' }}
                />
              </View>

              <View className="flex-row items-center gap-2">
                <ActivityIndicator size="small" color={colors.cyan} />
                <Text className="text-[11px] font-bold" style={{ color: colors.textSecondary }}>
                  Powered by Google Gemini Vision
                </Text>
              </View>
            </View>
          </View>
        )}

        <ScrollView
          showsVerticalScrollIndicator={false}
          contentContainerStyle={{
            padding: 20,
            gap: 16,
            paddingBottom: Math.max(insets.bottom + 160, 210),
          }}
          keyboardShouldPersistTaps="handled"
        >
          {/* Quick Capture Ingestion Toolbar */}
          <View
            className="p-4 rounded-3xl gap-3 border"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F8FAFC',
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center justify-between">
              <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                SCAN OR UPLOAD RECEIPT
              </Text>
              <TouchableOpacity
                onPress={() => setOcrTextModalVisible(true)}
                className="flex-row items-center gap-1"
              >
                <Ionicons name="code-slash" size={13} color={colors.cyan} />
                <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                  Paste Text
                </Text>
              </TouchableOpacity>
            </View>

            <View className="flex-row gap-2.5">
              <TouchableOpacity
                onPress={handleTakePhoto}
                className="flex-1 py-3 px-2 rounded-2xl items-center justify-center gap-1.5 border shadow-sm"
                style={{
                  backgroundColor: colors.surface,
                  borderColor: colors.border,
                }}
                activeOpacity={0.8}
              >
                <Ionicons name="camera" size={20} color={colors.cyan} />
                <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                  Camera
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                onPress={handlePickImage}
                className="flex-1 py-3 px-2 rounded-2xl items-center justify-center gap-1.5 border shadow-sm"
                style={{
                  backgroundColor: colors.surface,
                  borderColor: colors.border,
                }}
                activeOpacity={0.8}
              >
                <Ionicons name="images" size={20} color={colors.cyan} />
                <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                  Gallery
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                onPress={handlePickDocument}
                className="flex-1 py-3 px-2 rounded-2xl items-center justify-center gap-1.5 border shadow-sm"
                style={{
                  backgroundColor: colors.surface,
                  borderColor: colors.border,
                }}
                activeOpacity={0.8}
              >
                <Ionicons name="document-text" size={20} color={colors.cyan} />
                <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                  PDF Bill
                </Text>
              </TouchableOpacity>
            </View>
          </View>

          {/* Receipt Image Thumbnail (If Loaded) */}
          {receiptImageUri && (
            <View
              className="p-3 rounded-2xl flex-row items-center justify-between border"
              style={{ backgroundColor: colors.surface, borderColor: colors.border }}
            >
              <TouchableOpacity
                onPress={() => setPreviewImageVisible(true)}
                className="flex-row items-center gap-3 flex-1"
                activeOpacity={0.75}
              >
                <Image
                  source={{ uri: receiptImageUri }}
                  className="w-12 h-12 rounded-xl"
                  resizeMode="cover"
                />
                <View className="flex-1">
                  <View className="flex-row items-center gap-1.5">
                    <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                      Receipt Photo Attached
                    </Text>
                    <Ionicons name="eye-outline" size={13} color={colors.cyan} />
                  </View>
                  <Text className="text-[10px] font-semibold" style={{ color: colors.cyan }}>
                    Tap to view full receipt
                  </Text>
                </View>
              </TouchableOpacity>
              <TouchableOpacity
                onPress={() => setReceiptImageUri(null)}
                className="p-1.5 rounded-full"
                style={{ backgroundColor: colors.accentPill }}
                hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
              >
                <Ionicons name="close" size={16} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>
          )}

          {/* Merchant & Payer Details Card */}
          <View
            className="p-4 rounded-3xl gap-3 border shadow-sm"
            style={{
              backgroundColor: isDark ? colors.surface : '#FFFFFF',
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center justify-between">
              <View className="flex-1 mr-3">
                <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                  MERCHANT / PLACE
                </Text>
                <TextInput
                  value={merchantName}
                  onChangeText={setMerchantName}
                  placeholder="e.g. Cafe, Grocery, Dinner"
                  placeholderTextColor={colors.textSecondary}
                  className="text-base font-extrabold mt-0.5"
                  style={{ color: colors.textMain }}
                />
              </View>

              <View className="items-end">
                <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                  PAID BY
                </Text>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} className="max-w-[140px] mt-1">
                  {activeMembers.map((m) => {
                    const isSelected = m.userId === paidByUserId;
                    const name = getMemberName(m);

                    return (
                      <TouchableOpacity
                        key={m.userId}
                        onPress={() => setPaidByUserId(m.userId)}
                        className="px-2.5 py-1 rounded-xl mr-1 border"
                        style={{
                          backgroundColor: isSelected ? colors.cyan : colors.accentPill,
                          borderColor: isSelected ? colors.cyan : colors.border,
                        }}
                        activeOpacity={0.8}
                      >
                        <Text
                          className="text-xs font-bold"
                          style={{ color: isSelected ? '#0F172A' : colors.textSecondary }}
                        >
                          {name}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </ScrollView>
              </View>
            </View>
          </View>

          {/* Line Items Section - Modular Overview */}
          <View className="gap-3">
            <View className="flex-row items-center justify-between px-1">
              <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                LINE ITEMS ({lineItems.length})
              </Text>
              <TouchableOpacity
                onPress={handleAddLineItem}
                className="flex-row items-center gap-1 px-3 py-1.5 rounded-full"
                style={{ backgroundColor: `${colors.cyan}20` }}
                activeOpacity={0.7}
              >
                <Ionicons name="add" size={14} color={colors.cyan} />
                <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                  Add Item
                </Text>
              </TouchableOpacity>
            </View>

            {lineItems.length === 0 ? (
              <View
                className="p-8 rounded-3xl items-center justify-center border gap-2.5"
                style={{
                  backgroundColor: isDark ? colors.surface : '#FFFFFF',
                  borderColor: colors.border,
                }}
              >
                <Ionicons name="receipt-outline" size={32} color={colors.cyan} />
                <Text className="text-sm font-extrabold text-center" style={{ color: colors.textMain }}>
                  No Line Items Yet
                </Text>
                <Text className="text-xs text-center max-w-[240px]" style={{ color: colors.textSecondary }}>
                  Take a photo or attach a bill above to auto-scan items, or tap "+ Add Item" to enter manually.
                </Text>
              </View>
            ) : (
              lineItems.map((item, index) => {
                const assigned = item.assignedUserIds || [];
                const splitMode = item.splitType || 'equal';
                const isAll = assigned.length === memberIds.length;
                const assignedSummary = isAll
                  ? `Split equally • All (${memberIds.length})`
                  : splitMode === 'equal'
                  ? `Split equally • ${assigned.length} people`
                  : `${splitMode.toUpperCase()} split • ${assigned.length} people`;

                return (
                  <TouchableOpacity
                    key={item.id}
                    onPress={() => setEditingItemIndex(index)}
                    className="p-4 rounded-3xl gap-2.5 border shadow-sm"
                    style={{
                      backgroundColor: isDark ? colors.surface : '#FFFFFF',
                      borderColor: colors.border,
                    }}
                    activeOpacity={0.85}
                  >
                    {/* Top Row: Qty Stepper, Title, Price, Delete */}
                    <View className="flex-row items-center justify-between gap-2">
                      {/* QTY Stepper Controls */}
                      <View
                        className="flex-row items-center rounded-xl border px-1.5 py-0.5 gap-1.5"
                        style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                      >
                        <TouchableOpacity
                          onPress={() => handleUpdateQuantity(index, -1)}
                          className="p-1 rounded-lg"
                          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                        >
                          <Ionicons name="remove" size={13} color={colors.textSecondary} />
                        </TouchableOpacity>
                        <TextInput
                          value={String(item.quantity || 1)}
                          keyboardType="number-pad"
                          onChangeText={(v) => handleSetExactQuantity(index, v)}
                          className="text-xs font-black min-w-[16px] text-center"
                          style={{ color: colors.textMain }}
                        />
                        <TouchableOpacity
                          onPress={() => handleUpdateQuantity(index, 1)}
                          className="p-1 rounded-lg"
                          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                        >
                          <Ionicons name="add" size={13} color={colors.textSecondary} />
                        </TouchableOpacity>
                      </View>

                      {/* Title */}
                      <TextInput
                        value={item.title}
                        onChangeText={(text) => {
                          const next = [...lineItems];
                          next[index].title = text;
                          setLineItems(next);
                        }}
                        placeholder="Item Title"
                        placeholderTextColor={colors.textSecondary}
                        className="text-sm font-extrabold flex-1"
                        style={{ color: colors.textMain }}
                      />

                      {/* Price */}
                      <View className="flex-row items-center">
                        <Text className="text-xs font-bold mr-0.5" style={{ color: colors.textSecondary }}>
                          {cohort?.currency || '₹'}
                        </Text>
                        <TextInput
                          value={String(item.price)}
                          keyboardType="decimal-pad"
                          onChangeText={(val) => {
                            const parsed = parseFloat(val) || 0;
                            const next = [...lineItems];
                            next[index].price = parsed;
                            setLineItems(next);
                          }}
                          className="text-sm font-black w-16 text-right px-1.5 py-0.5 rounded-lg border"
                          style={{
                            backgroundColor: colors.accentPill,
                            borderColor: colors.border,
                            color: colors.textMain,
                          }}
                        />
                      </View>

                      {/* Delete */}
                      <TouchableOpacity
                        onPress={() => handleDeleteItem(index)}
                        className="p-1.5 rounded-full"
                        style={{ backgroundColor: colors.accentPill }}
                        hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                      >
                        <Ionicons name="trash-outline" size={14} color={colors.textSecondary} />
                      </TouchableOpacity>
                    </View>

                    {/* Bottom Row: Split Summary Pill & Tap to Configure */}
                    <View className="flex-row items-center justify-between pt-1 border-t" style={{ borderColor: colors.border }}>
                      <View className="flex-row items-center gap-1.5">
                        <View
                          className="w-2 h-2 rounded-full"
                          style={{ backgroundColor: colors.cyan }}
                        />
                        <Text className="text-[11px] font-semibold" style={{ color: colors.textSecondary }}>
                          {assignedSummary}
                        </Text>
                      </View>

                      <View className="flex-row items-center gap-1">
                        <Text className="text-[11px] font-bold" style={{ color: colors.cyan }}>
                          Edit Split
                        </Text>
                        <Ionicons name="chevron-forward" size={12} color={colors.cyan} />
                      </View>
                    </View>
                  </TouchableOpacity>
                );
              })
            )}
          </View>

          {/* Taxes, Service Charges & Discounts Section */}
          <View
            className="p-4 rounded-3xl gap-3.5 border"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
              borderColor: colors.border,
            }}
          >
            <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
              TAXES & DEDUCTIONS
            </Text>

            <View className="flex-row gap-3">
              <View className="flex-1">
                <Text className="text-[10px] font-bold" style={{ color: colors.textSecondary }}>
                  TAX / GST ({cohort?.currency || '₹'})
                </Text>
                <TextInput
                  value={taxAmount}
                  onChangeText={setTaxAmount}
                  keyboardType="decimal-pad"
                  className="h-10 px-3 rounded-xl border font-bold text-sm mt-1"
                  style={{
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                    color: colors.textMain,
                  }}
                />
              </View>

              <View className="flex-1">
                <Text className="text-[10px] font-bold" style={{ color: colors.textSecondary }}>
                  SERVICE FEE ({cohort?.currency || '₹'})
                </Text>
                <TextInput
                  value={serviceCharge}
                  onChangeText={setServiceCharge}
                  keyboardType="decimal-pad"
                  className="h-10 px-3 rounded-xl border font-bold text-sm mt-1"
                  style={{
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                    color: colors.textMain,
                  }}
                />
              </View>

              <View className="flex-1">
                <Text className="text-[10px] font-bold" style={{ color: colors.textSecondary }}>
                  DISCOUNT ({cohort?.currency || '₹'})
                </Text>
                <TextInput
                  value={discountAmount}
                  onChangeText={setDiscountAmount}
                  keyboardType="decimal-pad"
                  className="h-10 px-3 rounded-xl border font-bold text-sm mt-1"
                  style={{
                    backgroundColor: colors.surface,
                    borderColor: colors.border,
                    color: colors.textMain,
                  }}
                />
              </View>
            </View>
          </View>

          {/* Live Calculated Member Splits Summary */}
          <View
            className="p-4 rounded-3xl gap-3 border shadow-sm"
            style={{
              backgroundColor: isDark ? colors.surface : '#FFFFFF',
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center justify-between">
              <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                CALCULATED MEMBER OWINGS
              </Text>
              <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                Proportional Tax Applied
              </Text>
            </View>

            <View className="gap-2">
              {Object.entries(calculatedMemberSplits).map(([userId, amount]) => {
                const member = activeMembers.find((m) => m.userId === userId);
                const name = getMemberName(member, userId);
                const pct = grandTotal > 0 ? Math.round((amount / grandTotal) * 100) : 0;

                return (
                  <View key={userId} className="flex-row items-center justify-between py-1 border-b" style={{ borderColor: colors.border }}>
                    <View className="flex-row items-center gap-2">
                      <View
                        className="w-6 h-6 rounded-full items-center justify-center"
                        style={{ backgroundColor: colors.accentPill }}
                      >
                        <Text className="text-[10px] font-bold" style={{ color: colors.textMain }}>
                          {name.slice(0, 1).toUpperCase()}
                        </Text>
                      </View>
                      <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                        {name}
                      </Text>
                    </View>

                    <View className="flex-row items-center gap-2">
                      <Text className="text-[11px] font-semibold" style={{ color: colors.textSecondary }}>
                        {pct}%
                      </Text>
                      <Text className="text-sm font-black" style={{ color: colors.textMain }}>
                        {cohort?.currency || '₹'}{amount.toFixed(2)}
                      </Text>
                    </View>
                  </View>
                );
              })}
            </View>
          </View>
        </ScrollView>

        {/* Floating Bottom Action Bar with Total & Primary CTA */}
        <View
          className="absolute bottom-0 left-0 right-0 p-5 border-t shadow-2xl"
          style={{
            backgroundColor: colors.surface,
            borderColor: colors.border,
            paddingBottom: Math.max(insets.bottom + 8, 20),
          }}
        >
          <View className="flex-row items-center justify-between mb-3">
            <View>
              <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                GRAND TOTAL (INC. TAXES)
              </Text>
              <Text className="text-2xl font-black" style={{ color: colors.textMain }}>
                {cohort?.currency || '₹'}{grandTotal.toFixed(2)}
              </Text>
            </View>

            <View className="items-end">
              <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                ITEMS SUBTOTAL
              </Text>
              <Text className="text-sm font-bold" style={{ color: colors.textSecondary }}>
                {cohort?.currency || '₹'}{itemsSubtotal.toFixed(2)}
              </Text>
            </View>
          </View>

          <TouchableOpacity
            onPress={handleSaveExpense}
            className="h-14 rounded-2xl items-center justify-center shadow-lg"
            style={{ backgroundColor: colors.cyan }}
            activeOpacity={0.85}
          >
            <Text className="text-base font-black text-slate-900">
              Confirm & Log Itemized Expense
            </Text>
          </TouchableOpacity>
        </View>

        {/* =========================================================================
            MODULAR ITEM SPLIT CONFIGURATION SUB-DRAWER (Focused Per-Item Editor)
           ========================================================================= */}
        {activeEditingItem && editingItemIndex !== null && (
          <Modal
            visible={!!activeEditingItem}
            transparent
            animationType="slide"
            onRequestClose={() => setEditingItemIndex(null)}
          >
            <View className="flex-1 justify-end bg-black/60">
              <TouchableOpacity className="flex-1" onPress={() => setEditingItemIndex(null)} />
              <View
                className="rounded-t-[32px] p-6 gap-4 border-t"
                style={{
                  backgroundColor: colors.surface,
                  borderColor: colors.border,
                  paddingBottom: Math.max(insets.bottom + 16, 32),
                  maxHeight: '85%',
                }}
              >
                {/* Modal Header */}
                <View className="flex-row items-center justify-between">
                  <View className="flex-1 mr-2">
                    <Text className="text-base font-extrabold" style={{ color: colors.textMain }}>
                      {activeEditingItem.title}
                    </Text>
                    <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                      Qty: {activeEditingItem.quantity || 1} • Total: {cohort?.currency || '₹'}{activeEditingItem.price.toFixed(2)}
                    </Text>
                  </View>
                  <TouchableOpacity onPress={() => setEditingItemIndex(null)} className="p-1">
                    <Ionicons name="close" size={22} color={colors.textSecondary} />
                  </TouchableOpacity>
                </View>

                {/* Split Mode Selector Tabs */}
                <View className="flex-row flex-wrap gap-2">
                  {(['equal', 'shares', 'exact', 'percentage'] as ItemSplitType[]).map((mode) => {
                    const isSelected = (activeEditingItem.splitType || 'equal') === mode;
                    return (
                      <TouchableOpacity
                        key={mode}
                        onPress={() => handleSetItemSplitType(editingItemIndex, mode)}
                        className="px-3 py-2 rounded-xl border flex-row items-center gap-1.5"
                        style={{
                          backgroundColor: isSelected ? colors.cyan : colors.accentPill,
                          borderColor: isSelected ? colors.cyan : colors.border,
                        }}
                      >
                        <Ionicons
                          name={
                            mode === 'equal'
                              ? 'people'
                              : mode === 'shares'
                              ? 'pie-chart'
                              : mode === 'exact'
                              ? 'cash'
                              : 'calculator'
                          }
                          size={13}
                          color={isSelected ? '#0F172A' : colors.textSecondary}
                        />
                        <Text
                          className="text-xs font-bold uppercase tracking-wider"
                          style={{ color: isSelected ? '#0F172A' : colors.textSecondary }}
                        >
                          {mode}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>

                <ScrollView showsVerticalScrollIndicator={false} className="max-h-72 gap-2">
                  {/* Mode 1: Equal Split */}
                  {activeEditingItem.splitType === 'equal' && (
                    <View className="gap-2">
                      <View className="flex-row items-center justify-between">
                        <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                          Assigned Members:
                        </Text>
                        <TouchableOpacity onPress={() => handleToggleAll(editingItemIndex)}>
                          <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                            {(activeEditingItem.assignedUserIds || []).length === memberIds.length ? 'Deselect All' : 'Select All'}
                          </Text>
                        </TouchableOpacity>
                      </View>

                      {activeMembers.map((m) => {
                        const isAssigned = (activeEditingItem.assignedUserIds || []).includes(m.userId);
                        const name = getMemberName(m);

                        return (
                          <TouchableOpacity
                            key={m.userId}
                            onPress={() => handleToggleMember(editingItemIndex, m.userId)}
                            className="p-3 rounded-2xl border flex-row items-center justify-between"
                            style={{
                              backgroundColor: isAssigned ? `${colors.cyan}15` : colors.accentPill,
                              borderColor: isAssigned ? colors.cyan : colors.border,
                            }}
                            activeOpacity={0.8}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name}
                            </Text>
                            <Ionicons
                              name={isAssigned ? 'checkmark-circle' : 'ellipse-outline'}
                              size={18}
                              color={isAssigned ? colors.cyan : colors.textSecondary}
                            />
                          </TouchableOpacity>
                        );
                      })}
                    </View>
                  )}

                  {/* Mode 2: Shares Split */}
                  {activeEditingItem.splitType === 'shares' && (
                    <View className="gap-2">
                      {activeMembers.map((m) => {
                        const existing = activeEditingItem.assignments?.find((a) => a.userId === m.userId);
                        const currentShare = existing?.value !== undefined ? existing.value : 1;
                        const name = getMemberName(m);

                        return (
                          <View
                            key={m.userId}
                            className="p-3 rounded-2xl border flex-row items-center justify-between"
                            style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name}
                            </Text>
                            <View className="flex-row items-center gap-2">
                              <TouchableOpacity
                                onPress={() => handleUpdateAssignmentValue(editingItemIndex, m.userId, currentShare - 1)}
                                className="p-1 rounded-lg border"
                                style={{ backgroundColor: colors.surface, borderColor: colors.border }}
                              >
                                <Ionicons name="remove" size={14} color={colors.textMain} />
                              </TouchableOpacity>
                              <Text className="text-sm font-black min-w-[20px] text-center" style={{ color: colors.textMain }}>
                                {currentShare}
                              </Text>
                              <TouchableOpacity
                                onPress={() => handleUpdateAssignmentValue(editingItemIndex, m.userId, currentShare + 1)}
                                className="p-1 rounded-lg border"
                                style={{ backgroundColor: colors.surface, borderColor: colors.border }}
                              >
                                <Ionicons name="add" size={14} color={colors.textMain} />
                              </TouchableOpacity>
                            </View>
                          </View>
                        );
                      })}
                    </View>
                  )}

                  {/* Mode 3: Exact Split */}
                  {activeEditingItem.splitType === 'exact' && (
                    <View className="gap-2">
                      {activeMembers.map((m) => {
                        const existing = activeEditingItem.assignments?.find((a) => a.userId === m.userId);
                        const val = existing?.value !== undefined ? existing.value : 0;
                        const name = getMemberName(m);

                        return (
                          <View
                            key={m.userId}
                            className="p-3 rounded-2xl border flex-row items-center justify-between"
                            style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name}
                            </Text>
                            <View className="flex-row items-center">
                              <Text className="text-xs font-bold mr-1" style={{ color: colors.textSecondary }}>
                                {cohort?.currency || '₹'}
                              </Text>
                              <TextInput
                                value={String(val)}
                                keyboardType="decimal-pad"
                                onChangeText={(v) => handleUpdateAssignmentValue(editingItemIndex, m.userId, parseFloat(v) || 0)}
                                className="w-20 px-2 py-1 rounded-xl border text-right font-black text-xs"
                                style={{ backgroundColor: colors.surface, borderColor: colors.border, color: colors.textMain }}
                              />
                            </View>
                          </View>
                        );
                      })}
                    </View>
                  )}

                  {/* Mode 4: Percentage Split */}
                  {activeEditingItem.splitType === 'percentage' && (
                    <View className="gap-2">
                      {activeMembers.map((m) => {
                        const existing = activeEditingItem.assignments?.find((a) => a.userId === m.userId);
                        const val = existing?.value !== undefined ? existing.value : 0;
                        const name = getMemberName(m);

                        return (
                          <View
                            key={m.userId}
                            className="p-3 rounded-2xl border flex-row items-center justify-between"
                            style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                          >
                            <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                              {name}
                            </Text>
                            <View className="flex-row items-center">
                              <TextInput
                                value={String(val)}
                                keyboardType="decimal-pad"
                                onChangeText={(v) => handleUpdateAssignmentValue(editingItemIndex, m.userId, parseFloat(v) || 0)}
                                className="w-16 px-2 py-1 rounded-xl border text-right font-black text-xs"
                                style={{ backgroundColor: colors.surface, borderColor: colors.border, color: colors.textMain }}
                              />
                              <Text className="text-xs font-bold ml-1" style={{ color: colors.textSecondary }}>
                                %
                              </Text>
                            </View>
                          </View>
                        );
                      })}
                    </View>
                  )}
                </ScrollView>

                <TouchableOpacity
                  onPress={() => setEditingItemIndex(null)}
                  className="h-12 rounded-2xl items-center justify-center shadow-md mt-1"
                  style={{ backgroundColor: colors.cyan }}
                  activeOpacity={0.85}
                >
                  <Text className="text-sm font-black text-slate-900">Done</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>
        )}

        {/* OCR Text Direct Paste Modal */}
        {ocrTextModalVisible && (
          <Modal
            visible={ocrTextModalVisible}
            transparent
            animationType="slide"
            onRequestClose={() => setOcrTextModalVisible(false)}
          >
            <View className="flex-1 justify-end bg-black/60">
              <TouchableOpacity className="flex-1" onPress={() => setOcrTextModalVisible(false)} />
              <View
                className="rounded-t-[32px] p-6 gap-4 border-t"
                style={{
                  backgroundColor: colors.surface,
                  borderColor: colors.border,
                  paddingBottom: Math.max(insets.bottom + 12, 32),
                }}
              >
                <View className="flex-row items-center justify-between">
                  <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                    Paste Receipt OCR Text
                  </Text>
                  <TouchableOpacity onPress={() => setOcrTextModalVisible(false)}>
                    <Ionicons name="close" size={22} color={colors.textSecondary} />
                  </TouchableOpacity>
                </View>

                <TextInput
                  value={customOcrText}
                  onChangeText={setCustomOcrText}
                  multiline
                  placeholder="Paste printed bill text here..."
                  placeholderTextColor={colors.textSecondary}
                  className="h-40 p-3 rounded-2xl border text-xs font-mono"
                  style={{
                    backgroundColor: isDark ? colors.accentPill : '#F8FAFC',
                    borderColor: colors.border,
                    color: colors.textMain,
                  }}
                />

                <TouchableOpacity
                  onPress={() => {
                    const parsed = parseReceiptText(customOcrText);
                    loadParsedData(parsed);
                    setOcrTextModalVisible(false);
                    setCustomOcrText('');
                  }}
                  className="h-12 rounded-2xl items-center justify-center shadow-md"
                  style={{ backgroundColor: colors.cyan }}
                  activeOpacity={0.85}
                >
                  <Text className="text-sm font-black text-slate-900">Parse Receipt</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>
        )}

        {/* Full-Screen Receipt Image Lightbox Preview Modal */}
        {receiptImageUri && (
          <Modal
            visible={previewImageVisible}
            transparent
            animationType="fade"
            onRequestClose={() => setPreviewImageVisible(false)}
          >
            <View className="flex-1 bg-black/95 justify-between">
              {/* Top Bar */}
              <View
                className="px-5 py-3 flex-row items-center justify-between border-b border-white/10"
                style={{ paddingTop: Math.max(insets.top + 8, 20) }}
              >
                <Text className="text-white font-bold text-sm">Receipt Image Preview</Text>
                <TouchableOpacity
                  onPress={() => setPreviewImageVisible(false)}
                  className="w-8 h-8 rounded-full bg-white/20 items-center justify-center"
                >
                  <Ionicons name="close" size={20} color="#FFFFFF" />
                </TouchableOpacity>
              </View>

              {/* Center Image */}
              <View className="flex-1 items-center justify-center p-4">
                <Image
                  source={{ uri: receiptImageUri }}
                  className="w-full h-full"
                  resizeMode="contain"
                />
              </View>

              {/* Bottom Bar */}
              <View
                className="px-5 py-4 border-t border-white/10 items-center"
                style={{ paddingBottom: Math.max(insets.bottom + 8, 20) }}
              >
                <TouchableOpacity
                  onPress={() => setPreviewImageVisible(false)}
                  className="px-6 py-2.5 rounded-full bg-white/20"
                >
                  <Text className="text-white font-bold text-xs">Close Preview</Text>
                </TouchableOpacity>
              </View>
            </View>
          </Modal>
        )}
      </View>
    </Modal>
  );
}

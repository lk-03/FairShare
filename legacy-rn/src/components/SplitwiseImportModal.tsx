import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  ScrollView,
  TextInput,
  ActivityIndicator,
  useColorScheme,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import * as DocumentPicker from 'expo-document-picker';
import { useExpenseStore } from '../store/useExpenseStore';
import { useThemeStore, getThemePalette, getActiveThemeClass } from '../store/useThemeStore';
import { showAlert } from '../store/useAlertStore';
import {
  parseSplitwisePreview,
  parseSplitwiseCsvForCohort,
  SplitwiseImportPreview,
  MemberAllocation,
} from '../utils/splitwiseImporter';
import { EventCohort, GroupMember } from '../types';

interface SplitwiseImportModalProps {
  visible: boolean;
  onClose: () => void;
  targetCohort?: EventCohort;
  onSuccess?: (cohortId: string) => void;
}

async function readPickedFileAsString(uri: string): Promise<string> {
  try {
    const res = await fetch(uri);
    const text = await res.text();
    if (text && text.trim().length > 0) {
      return text;
    }
  } catch {
    // Continue
  }

  try {
    const legacyFS = await import('expo-file-system/legacy');
    if (legacyFS && legacyFS.readAsStringAsync) {
      return await legacyFS.readAsStringAsync(uri);
    }
  } catch {
    // Continue
  }

  try {
    const { File } = await import('expo-file-system');
    if (File) {
      const file = new File(uri);
      return await file.text();
    }
  } catch {
    // Continue
  }

  throw new Error('Unable to read selected CSV. Please try pasting the CSV content directly.');
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

export function SplitwiseImportModal({
  visible,
  onClose,
  targetCohort,
  onSuccess,
}: SplitwiseImportModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const { currentUser, cohorts, members, importCsvIntoCohort } = useExpenseStore();

  const [selectedCohortId, setSelectedCohortId] = useState<string>(
    targetCohort?.id || cohorts[0]?.id || ''
  );
  const [groupDropdownVisible, setGroupDropdownVisible] = useState(false);

  useEffect(() => {
    if (targetCohort) {
      setSelectedCohortId(targetCohort.id);
    } else if (cohorts.length > 0 && !selectedCohortId) {
      setSelectedCohortId(cohorts[0].id);
    }
  }, [targetCohort, cohorts]);

  const activeCohort = cohorts.find((c) => c.id === selectedCohortId) || targetCohort || cohorts[0];
  const activeCohortMembers = activeCohort ? members[activeCohort.id] || [] : [];

  const [inputMode, setInputMode] = useState<'file' | 'paste'>('file');
  const [pastedCsv, setPastedCsv] = useState('');
  const [selectedFileName, setSelectedFileName] = useState<string | null>(null);
  const [rawCsvContent, setRawCsvContent] = useState<string | null>(null);
  const [showTutorial, setShowTutorial] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [csvPreview, setCsvPreview] = useState<SplitwiseImportPreview | null>(null);
  const [allocations, setAllocations] = useState<Record<string, MemberAllocation>>({});

  // Multi-Phase Progress Bar State
  const [isImporting, setIsImporting] = useState(false);
  const [importProgress, setImportProgress] = useState(0);
  const [importPhaseText, setImportPhaseText] = useState('Preparing import...');

  const handlePickDocument = async () => {
    try {
      setIsProcessing(true);
      const result = await DocumentPicker.getDocumentAsync({
        type: ['text/csv', 'text/comma-separated-values', 'text/plain', '*/*'],
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets && result.assets[0]) {
        const asset = result.assets[0];
        setSelectedFileName(asset.name);

        const content = await readPickedFileAsString(asset.uri);
        setRawCsvContent(content);
        processCsv(content);
      }
    } catch (err: any) {
      showAlert('Error Reading File', err.message || 'Could not read selected CSV file.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleProcessPasted = () => {
    if (!pastedCsv.trim()) {
      showAlert('Empty CSV', 'Please paste the contents of your Splitwise export.csv.');
      return;
    }
    setRawCsvContent(pastedCsv);
    processCsv(pastedCsv);
  };

  const processCsv = (content: string) => {
    try {
      const preview = parseSplitwisePreview(content);
      setCsvPreview(preview);

      const initialAllocations: Record<string, MemberAllocation> = {};
      const currentUserName = (currentUser.nickname || currentUser.fullName || '').toLowerCase();

      preview.memberNames.forEach((name) => {
        const lower = name.toLowerCase();

        // 1. Match current logged in user
        if (lower === currentUserName || lower === 'you' || lower === currentUser.fullName.toLowerCase()) {
          initialAllocations[name] = {
            type: 'assign',
            targetUserId: currentUser.id,
            targetName: `${currentUser.fullName} (You)`,
          };
          return;
        }

        // 2. Match existing member in target cohort
        const matchedMember = activeCohortMembers.find((m) => {
          const mName = (m.profile?.nickname || m.profile?.fullName || '').toLowerCase();
          return mName === lower;
        });

        if (matchedMember) {
          initialAllocations[name] = {
            type: 'assign',
            targetUserId: matchedMember.userId,
            targetName: matchedMember.profile?.fullName || matchedMember.profile?.nickname || name,
          };
          return;
        }

        // 3. Default to Shadow Member
        initialAllocations[name] = {
          type: 'shadow',
          shadowName: name,
        };
      });

      setAllocations(initialAllocations);
    } catch (err: any) {
      showAlert('Invalid Splitwise CSV', err.message || 'Failed to parse CSV file.');
      setCsvPreview(null);
    }
  };

  const handleConfirmImport = async () => {
    if (!rawCsvContent || !activeCohort) {
      showAlert('Error', 'Please select a group and provide CSV content.');
      return;
    }

    try {
      setIsImporting(true);
      setImportProgress(15);
      setImportPhaseText('Reading and parsing CSV records...');
      await sleep(250);

      setImportProgress(45);
      setImportPhaseText('Allocating members & building debt splits...');
      await sleep(300);

      const result = parseSplitwiseCsvForCohort(
        activeCohort.id,
        rawCsvContent,
        allocations,
        activeCohortMembers
      );

      setImportProgress(80);
      setImportPhaseText('Optimizing local cache & calculating ledger balances...');
      await sleep(350);

      importCsvIntoCohort(activeCohort.id, result.newShadowMembers, result.expenses);

      setImportProgress(100);
      setImportPhaseText('Import complete!');
      await sleep(200);

      const shadowCount = result.newShadowMembers.length;
      const assignedCount = Object.keys(allocations).length - shadowCount;

      setIsImporting(false);

      showAlert(
        'Import Successful!',
        `Successfully imported ${result.expenses.length} transactions into "${activeCohort.name}".\n\n- ${assignedCount} members mapped to group\n- ${shadowCount} preserved as shadow members`,
        [
          {
            text: 'View Group',
            style: 'default',
            onPress: () => {
              resetState();
              onClose();
              if (onSuccess) onSuccess(activeCohort.id);
            },
          },
        ]
      );
    } catch (err: any) {
      setIsImporting(false);
      showAlert('Import Failed', err.message || 'Could not import CSV transactions.');
    }
  };

  const resetState = () => {
    setSelectedFileName(null);
    setRawCsvContent(null);
    setPastedCsv('');
    setCsvPreview(null);
    setAllocations({});
    setShowTutorial(false);
    setIsImporting(false);
    setImportProgress(0);
  };

  if (!activeCohort && visible) {
    return (
      <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
        <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
          <View
            className="rounded-t-[32px] p-6 gap-4"
            style={{ backgroundColor: colors.surface }}
          >
            <View className="flex-row items-center justify-between">
              <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                No Groups Found
              </Text>
              <TouchableOpacity onPress={onClose}>
                <Ionicons name="close" size={22} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>
            <Text className="text-sm font-semibold" style={{ color: colors.textSecondary }}>
              Please create a group first (with your current roommates/friends) before importing Splitwise history into it.
            </Text>
            <TouchableOpacity
              onPress={onClose}
              className="h-12 rounded-2xl items-center justify-center mt-2"
              style={{ backgroundColor: colors.cyan }}
            >
              <Text className="text-sm font-black text-slate-900">Got It</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    );
  }

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
        <View
          className="rounded-t-[32px] p-5 gap-4"
          style={{
            backgroundColor: colors.surface,
            maxHeight: '92%',
          }}
        >
          {/* Header */}
          <View className="flex-row items-center justify-between">
            <View className="flex-row items-center gap-2.5">
              <View
                className="w-10 h-10 rounded-2xl items-center justify-center"
                style={{ backgroundColor: `${colors.emerald}20` }}
              >
                <Ionicons name="swap-horizontal" size={20} color={colors.emerald} />
              </View>
              <View>
                <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                  Import History into Group
                </Text>
                <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                  Admin tool for Splitwise export.csv
                </Text>
              </View>
            </View>
            <TouchableOpacity
              onPress={() => {
                resetState();
                onClose();
              }}
              className="p-1 rounded-xl"
              activeOpacity={0.7}
            >
              <Ionicons name="close" size={22} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-4 pb-4">
            {/* Dropdown Group Selector Card */}
            <TouchableOpacity
              onPress={() => {
                if (cohorts.length > 1) {
                  setGroupDropdownVisible(true);
                }
              }}
              activeOpacity={cohorts.length > 1 ? 0.75 : 1}
              className="p-3.5 rounded-2xl flex-row items-center justify-between"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#F8FAFC',
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <View className="flex-row items-center gap-3">
                <View
                  className="w-10 h-10 rounded-2xl items-center justify-center"
                  style={{ backgroundColor: `${colors.cyan}20` }}
                >
                  <Ionicons name="people" size={20} color={colors.cyan} />
                </View>
                <View>
                  <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
                    TARGET GROUP {cohorts.length > 1 ? '(TAP TO CHANGE)' : ''}
                  </Text>
                  <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                    {activeCohort?.name}
                  </Text>
                  <Text className="text-[11px] font-semibold" style={{ color: colors.textSecondary }}>
                    {activeCohortMembers.length} existing members
                  </Text>
                </View>
              </View>

              {cohorts.length > 1 && (
                <View className="flex-row items-center gap-1 bg-surface px-2.5 py-1.5 rounded-xl border border-border">
                  <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                    Change
                  </Text>
                  <Ionicons name="chevron-down" size={14} color={colors.cyan} />
                </View>
              )}
            </TouchableOpacity>

            {/* How to Export Guide Accordion */}
            <View
              className="rounded-2xl overflow-hidden"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <TouchableOpacity
                className="flex-row items-center justify-between p-3.5"
                onPress={() => setShowTutorial(!showTutorial)}
                activeOpacity={0.7}
              >
                <View className="flex-row items-center gap-2">
                  <Ionicons name="help-circle-outline" size={18} color={colors.cyan} />
                  <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                    How to export CSV from Splitwise
                  </Text>
                </View>
                <Ionicons
                  name={showTutorial ? 'chevron-up' : 'chevron-down'}
                  size={16}
                  color={colors.textSecondary}
                />
              </TouchableOpacity>

              {showTutorial && (
                <View className="px-4 pb-4 gap-2.5 border-t border-border pt-3">
                  <Text className="text-xs text-secondary leading-relaxed">
                    1. Open Splitwise app or web $\rightarrow$ Tap your group.
                  </Text>
                  <Text className="text-xs text-secondary leading-relaxed">
                    2. Tap Group Settings (Gear icon) $\rightarrow$ Scroll to "Advanced settings".
                  </Text>
                  <Text className="text-xs text-secondary leading-relaxed">
                    3. Tap "Export as spreadsheet" or "Export as CSV" $\rightarrow$ Save <Text className="font-mono" style={{ color: colors.cyan }}>export.csv</Text>.
                  </Text>
                  <Text className="text-xs text-secondary leading-relaxed">
                    4. Choose the file below or paste its content.
                  </Text>
                </View>
              )}
            </View>

            {/* Step 1: Upload / Input Mode */}
            {!csvPreview && (
              <View className="gap-3">
                <View className="flex-row rounded-2xl p-1 bg-surface border border-border">
                  <TouchableOpacity
                    onPress={() => setInputMode('file')}
                    className="flex-1 py-2.5 rounded-xl items-center"
                    style={{ backgroundColor: inputMode === 'file' ? colors.cyan : 'transparent' }}
                  >
                    <Text
                      className="text-xs font-bold"
                      style={{ color: inputMode === 'file' ? '#0F172A' : colors.textSecondary }}
                    >
                      Choose CSV File
                    </Text>
                  </TouchableOpacity>

                  <TouchableOpacity
                    onPress={() => setInputMode('paste')}
                    className="flex-1 py-2.5 rounded-xl items-center"
                    style={{ backgroundColor: inputMode === 'paste' ? colors.cyan : 'transparent' }}
                  >
                    <Text
                      className="text-xs font-bold"
                      style={{ color: inputMode === 'paste' ? '#0F172A' : colors.textSecondary }}
                    >
                      Paste CSV Text
                    </Text>
                  </TouchableOpacity>
                </View>

                {inputMode === 'file' ? (
                  <TouchableOpacity
                    onPress={handlePickDocument}
                    disabled={isProcessing}
                    className="border-2 border-dashed rounded-3xl p-6 items-center justify-center gap-3"
                    style={{
                      borderColor: colors.border,
                      backgroundColor: isDark ? '#0B0F17' : '#F8FAFC',
                    }}
                    activeOpacity={0.7}
                  >
                    {isProcessing ? (
                      <ActivityIndicator size="small" color={colors.cyan} />
                    ) : (
                      <>
                        <View
                          className="w-12 h-12 rounded-full items-center justify-center"
                          style={{ backgroundColor: `${colors.cyan}20` }}
                        >
                          <Ionicons name="cloud-upload-outline" size={24} color={colors.cyan} />
                        </View>
                        <View className="w-full items-center justify-center gap-1">
                          <Text
                            className="text-sm font-bold text-center w-full"
                            style={{ color: colors.textMain, textAlign: 'center' }}
                          >
                            Tap to browse export.csv
                          </Text>
                          <Text
                            className="text-xs font-semibold text-center w-full"
                            style={{ color: colors.textSecondary, textAlign: 'center' }}
                          >
                            Select the CSV file downloaded from Splitwise
                          </Text>
                        </View>
                      </>
                    )}
                  </TouchableOpacity>
                ) : (
                  <View className="gap-3">
                    <TextInput
                      className="h-32 p-3.5 rounded-2xl text-xs font-mono"
                      style={{
                        backgroundColor: colors.accentPill,
                        borderWidth: 1,
                        borderColor: colors.border,
                        color: colors.textMain,
                        textAlignVertical: 'top',
                      }}
                      placeholder="Paste your Splitwise CSV text here..."
                      placeholderTextColor={colors.textSecondary}
                      multiline
                      value={pastedCsv}
                      onChangeText={setPastedCsv}
                    />
                    <TouchableOpacity
                      onPress={handleProcessPasted}
                      className="h-12 rounded-2xl items-center justify-center"
                      style={{ backgroundColor: colors.cyan }}
                      activeOpacity={0.8}
                    >
                      <Text className="text-sm font-black text-slate-900">
                        Parse CSV Content
                      </Text>
                    </TouchableOpacity>
                  </View>
                )}
              </View>
            )}

            {/* Step 2: Member Allocation Matrix */}
            {csvPreview && (
              <View className="gap-4">
                {/* Stats Summary */}
                <View
                  className="p-4 rounded-3xl gap-3"
                  style={{
                    backgroundColor: isDark ? colors.accentPill : '#F8FAFC',
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <View className="flex-row items-center justify-between">
                    <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
                      CSV SUMMARY
                    </Text>
                    <TouchableOpacity onPress={resetState} activeOpacity={0.7}>
                      <Text className="text-xs font-bold text-rose-500">Change File</Text>
                    </TouchableOpacity>
                  </View>

                  <View className="flex-row items-center justify-between gap-2 pt-1">
                    <View
                      className="flex-1 p-2.5 rounded-xl border items-center"
                      style={{ backgroundColor: colors.surface, borderColor: colors.border }}
                    >
                      <Text className="text-base font-black" style={{ color: colors.cyan }}>
                        {csvPreview.totalTransactions}
                      </Text>
                      <Text className="text-[10px] font-bold uppercase" style={{ color: colors.textSecondary }}>
                        Transactions
                      </Text>
                    </View>

                    <View
                      className="flex-1 p-2.5 rounded-xl border items-center"
                      style={{ backgroundColor: colors.surface, borderColor: colors.border }}
                    >
                      <Text className="text-base font-black" style={{ color: colors.emerald }}>
                        {csvPreview.memberNames.length}
                      </Text>
                      <Text className="text-[10px] font-bold uppercase" style={{ color: colors.textSecondary }}>
                        CSV Members
                      </Text>
                    </View>

                    <View
                      className="flex-1 p-2.5 rounded-xl border items-center"
                      style={{ backgroundColor: colors.surface, borderColor: colors.border }}
                    >
                      <Text className="text-base font-black" style={{ color: colors.textMain }} numberOfLines={1}>
                        ₹{csvPreview.totalTurnover.toFixed(0)}
                      </Text>
                      <Text className="text-[10px] font-bold uppercase" style={{ color: colors.textSecondary }}>
                        Total Spend
                      </Text>
                    </View>
                  </View>

                  <Text className="text-[11px] font-semibold text-center mt-0.5" style={{ color: colors.textSecondary }}>
                    Total Group Spend is the sum of all imported bills ({csvPreview.startDate || 'Start'} to {csvPreview.endDate || 'End'})
                  </Text>
                </View>

                {/* Member Allocation Matrix */}
                <View
                  className="p-4 rounded-3xl gap-3"
                  style={{
                    backgroundColor: colors.surface,
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <View>
                    <Text className="text-xs font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
                      MEMBER ALLOCATION MATRIX
                    </Text>
                    <Text className="text-xs font-semibold mt-0.5" style={{ color: colors.textSecondary }}>
                      Assign each CSV name to a current member, or keep as a preserved shadow member (e.g. past roommates).
                    </Text>
                  </View>

                  <View className="gap-2.5 pt-1">
                    {csvPreview.memberNames.map((csvName) => {
                      const currentAlloc = allocations[csvName] || { type: 'shadow', shadowName: csvName };
                      const isAssigned = currentAlloc.type === 'assign';

                      return (
                        <View
                          key={csvName}
                          className="p-3 rounded-2xl border gap-2"
                          style={{
                            backgroundColor: isDark ? colors.accentPill : '#F8FAFC',
                            borderColor: colors.border,
                          }}
                        >
                          <View className="flex-row items-center justify-between">
                            <View className="flex-row items-center gap-2">
                              <View
                                className="w-7 h-7 rounded-full items-center justify-center"
                                style={{ backgroundColor: isAssigned ? `${colors.cyan}20` : `${colors.textSecondary}20` }}
                              >
                                <Ionicons
                                  name={isAssigned ? 'person' : 'person-outline'}
                                  size={13}
                                  color={isAssigned ? colors.cyan : colors.textSecondary}
                                />
                              </View>
                              <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                                {csvName}
                              </Text>
                            </View>

                            <View
                              className="px-2 py-0.5 rounded-full"
                              style={{
                                backgroundColor: isAssigned ? `${colors.emerald}20` : `${colors.cyan}20`,
                              }}
                            >
                              <Text
                                className="text-[10px] font-bold"
                                style={{ color: isAssigned ? colors.emerald : colors.cyan }}
                              >
                                {isAssigned ? 'Assigned' : 'Shadow Member'}
                              </Text>
                            </View>
                          </View>

                          {/* Allocation Option Selector */}
                          <ScrollView
                            horizontal
                            showsHorizontalScrollIndicator={false}
                            contentContainerClassName="gap-1.5 pt-1"
                          >
                            {/* Option 1: Shadow Member */}
                            <TouchableOpacity
                              onPress={() => {
                                setAllocations({
                                  ...allocations,
                                  [csvName]: { type: 'shadow', shadowName: csvName },
                                });
                              }}
                              className="px-2.5 py-1.5 rounded-xl flex-row items-center gap-1"
                              style={{
                                backgroundColor: !isAssigned ? colors.cyan : colors.surface,
                                borderWidth: 1,
                                borderColor: !isAssigned ? colors.cyan : colors.border,
                              }}
                              activeOpacity={0.75}
                            >
                              <Ionicons
                                name="cloud-outline"
                                size={12}
                                color={!isAssigned ? '#0F172A' : colors.textSecondary}
                              />
                              <Text
                                className="text-xs font-bold"
                                style={{ color: !isAssigned ? '#0F172A' : colors.textMain }}
                              >
                                Keep as Shadow
                              </Text>
                            </TouchableOpacity>

                            {/* Option 2: Current Group Members (including You) */}
                            {activeCohortMembers.map((member) => {
                              const isSelected =
                                isAssigned && currentAlloc.targetUserId === member.userId;
                              const isCurrentUser = member.userId === currentUser.id;
                              const memberName = isCurrentUser
                                ? `${currentUser.fullName} (You)`
                                : member.profile?.fullName || member.profile?.nickname || 'Member';

                              return (
                                <TouchableOpacity
                                  key={member.userId}
                                  onPress={() => {
                                    setAllocations({
                                      ...allocations,
                                      [csvName]: {
                                        type: 'assign',
                                        targetUserId: member.userId,
                                        targetName: memberName,
                                      },
                                    });
                                  }}
                                  className="px-2.5 py-1.5 rounded-xl flex-row items-center gap-1"
                                  style={{
                                    backgroundColor: isSelected ? colors.emerald : colors.surface,
                                    borderWidth: 1,
                                    borderColor: isSelected ? colors.emerald : colors.border,
                                  }}
                                  activeOpacity={0.75}
                                >
                                  <Ionicons
                                    name={isSelected ? 'checkmark-circle' : 'person-outline'}
                                    size={12}
                                    color={isSelected ? '#0F172A' : colors.textSecondary}
                                  />
                                  <Text
                                    className="text-xs font-bold"
                                    style={{ color: isSelected ? '#0F172A' : colors.textMain }}
                                  >
                                    {memberName}
                                  </Text>
                                </TouchableOpacity>
                              );
                            })}
                          </ScrollView>
                        </View>
                      );
                    })}
                  </View>
                </View>

                {/* Import CTA Button */}
                <TouchableOpacity
                  onPress={handleConfirmImport}
                  disabled={isImporting}
                  className="h-14 rounded-2xl items-center justify-center shadow-lg"
                  style={{ backgroundColor: colors.cyan }}
                  activeOpacity={0.85}
                >
                  <Text className="text-base font-black text-slate-900">
                    Import {csvPreview.totalTransactions} Transactions into {activeCohort.name}
                  </Text>
                </TouchableOpacity>
              </View>
            )}
          </ScrollView>
        </View>
      </View>

      {/* Dropdown Group Selector Bottom Sheet Modal */}
      <Modal
        visible={groupDropdownVisible}
        transparent
        animationType="fade"
        onRequestClose={() => setGroupDropdownVisible(false)}
      >
        <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
          <TouchableOpacity
            className="flex-1"
            activeOpacity={1}
            onPress={() => setGroupDropdownVisible(false)}
          />
          <View
            className="rounded-t-[32px] p-6 gap-4 border-t"
            style={{ backgroundColor: colors.surface, borderColor: colors.border }}
          >
            <View className="flex-row items-center justify-between">
              <Text className="text-lg font-bold" style={{ color: colors.textMain }}>
                Select Target Group
              </Text>
              <TouchableOpacity onPress={() => setGroupDropdownVisible(false)}>
                <Ionicons name="close" size={22} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>

            <ScrollView className="max-h-72 gap-2">
              {cohorts.map((c) => {
                const isSelected = c.id === selectedCohortId;
                const cMembers = members[c.id] || [];

                return (
                  <TouchableOpacity
                    key={c.id}
                    onPress={() => {
                      setSelectedCohortId(c.id);
                      setGroupDropdownVisible(false);
                      if (rawCsvContent) processCsv(rawCsvContent);
                    }}
                    className="p-3.5 rounded-2xl border flex-row items-center justify-between mb-2"
                    style={{
                      backgroundColor: isSelected ? `${colors.cyan}15` : isDark ? colors.accentPill : '#F8FAFC',
                      borderColor: isSelected ? colors.cyan : colors.border,
                    }}
                    activeOpacity={0.75}
                  >
                    <View className="flex-row items-center gap-3">
                      <View
                        className="w-10 h-10 rounded-xl items-center justify-center"
                        style={{ backgroundColor: isSelected ? colors.cyan : colors.surface }}
                      >
                        <Ionicons
                          name="people"
                          size={18}
                          color={isSelected ? '#0F172A' : colors.textSecondary}
                        />
                      </View>
                      <View>
                        <Text className="text-sm font-bold" style={{ color: colors.textMain }}>
                          {c.name}
                        </Text>
                        <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                          {cMembers.length} members
                        </Text>
                      </View>
                    </View>

                    {isSelected && (
                      <Ionicons name="checkmark-circle" size={20} color={colors.cyan} />
                    )}
                  </TouchableOpacity>
                );
              })}
            </ScrollView>
          </View>
        </View>
      </Modal>

      {/* Animated Multi-Phase Progress Bar Modal */}
      <Modal visible={isImporting} transparent animationType="fade">
        <View className={`flex-1 ${activeThemeClass} bg-black/70 items-center justify-center p-6`}>
          <View
            className="w-full max-w-sm rounded-3xl p-6 gap-4 border shadow-2xl items-center"
            style={{ backgroundColor: colors.surface, borderColor: colors.border }}
          >
            <View
              className="w-14 h-14 rounded-full items-center justify-center"
              style={{ backgroundColor: `${colors.cyan}20` }}
            >
              <ActivityIndicator size="small" color={colors.cyan} />
            </View>

            <View className="items-center gap-1 text-center">
              <Text className="text-lg font-black text-center" style={{ color: colors.textMain }}>
                Importing Splitwise History
              </Text>
              <Text className="text-xs font-semibold text-center" style={{ color: colors.textSecondary }}>
                {importPhaseText}
              </Text>
            </View>

            {/* Progress Bar Container */}
            <View className="w-full gap-2 pt-2">
              <View
                className="w-full h-3 rounded-full overflow-hidden border"
                style={{ backgroundColor: isDark ? colors.accentPill : '#F1F5F9', borderColor: colors.border }}
              >
                <View
                  className="h-full rounded-full transition-all duration-200"
                  style={{
                    width: `${importProgress}%`,
                    backgroundColor: colors.cyan,
                  }}
                />
              </View>
              <View className="flex-row items-center justify-between px-1">
                <Text className="text-[10px] font-bold uppercase" style={{ color: colors.cyan }}>
                  Processing
                </Text>
                <Text className="text-[11px] font-black" style={{ color: colors.textMain }}>
                  {importProgress}%
                </Text>
              </View>
            </View>
          </View>
        </View>
      </Modal>
    </Modal>
  );
}

import React, { useState, useMemo } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
  Modal,
  Switch,
  ScrollView,
  useColorScheme,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { SharedListItem, PersonalReminderSettings, ReminderFrequencyUnit } from '@/types';
import { Text } from '@/components/ui/Text';

interface NeedsListTabProps {
  cohortId: string;
}

const CREATIVE_REMINDERS = [
  'Check the list before Blinkiting, BigBasketing, or Instamarting!',
  'Don\'t double-order! Review house needs before checkout.',
  'Someone might have added eggs or milk—peek at the list first!',
  'Buying groceries? Tap off checked items to keep the house synced.',
  'Household Hero Alert: Check the Cart of the House list now!',
];

const HOUR_OPTIONS = [2, 4, 6, 8, 12, 24];
const DAY_OPTIONS = [1, 2, 3, 5, 7];
const TIME_OPTIONS = [
  { label: 'Morning (9 AM)', value: '09:00' },
  { label: 'Noon (1 PM)', value: '13:00' },
  { label: 'Evening (6 PM)', value: '18:00' },
  { label: 'Night (9 PM)', value: '21:00' },
];

export function NeedsListTab({ cohortId }: NeedsListTabProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const {
    sharedLists,
    reminderSettings,
    currentUser,
    addListItem,
    toggleListItem,
    deleteListItem,
    updateReminderSettings,
  } = useExpenseStore();

  const [newItemTitle, setNewItemTitle] = useState('');
  const [settingsVisible, setSettingsVisible] = useState(false);

  const cohortList = sharedLists[cohortId] || [];
  const currentSettings: PersonalReminderSettings = reminderSettings[cohortId] || {
    enabled: true,
    frequencyUnit: 'hours',
    frequencyHours: 6,
    frequencyDays: 1,
    reminderTime: '18:00',
    notifyStaleItems: true,
  };

  // Filter out items checked > 5 days ago (5 days = 5 * 86400000 ms)
  const activeList = useMemo(() => {
    const FIVE_DAYS_MS = 5 * 86400000;
    const now = Date.now();

    return cohortList.filter((item) => {
      if (!item.isCompleted || !item.completedAt) return true;
      const completedTime = new Date(item.completedAt).getTime();
      return now - completedTime < FIVE_DAYS_MS;
    });
  }, [cohortList]);

  // Pick a random creative reminder for this session
  const randomReminder = useMemo(() => {
    const idx = Math.floor(Math.random() * CREATIVE_REMINDERS.length);
    return CREATIVE_REMINDERS[idx];
  }, []);

  const handleAddItem = () => {
    if (!newItemTitle.trim()) return;

    const newItem: SharedListItem = {
      id: `item_${Date.now()}`,
      cohortId,
      title: newItemTitle.trim(),
      addedByUserId: currentUser.id,
      isCompleted: false,
      createdAt: new Date().toISOString(),
    };

    addListItem(newItem);
    setNewItemTitle('');
  };

  // Modal Settings State
  const [enabled, setEnabled] = useState(currentSettings.enabled ?? true);
  const [unit, setUnit] = useState<ReminderFrequencyUnit>(currentSettings.frequencyUnit || 'hours');
  const [freqHours, setFreqHours] = useState(currentSettings.frequencyHours || 6);
  const [freqDays, setFreqDays] = useState(currentSettings.frequencyDays || 1);
  const [reminderTime, setReminderTime] = useState(currentSettings.reminderTime || '18:00');
  const [notifyStale, setNotifyStale] = useState(currentSettings.notifyStaleItems ?? true);

  const handleSaveSettings = () => {
    updateReminderSettings(cohortId, {
      enabled,
      frequencyUnit: unit,
      frequencyHours: freqHours,
      frequencyDays: freqDays,
      reminderTime,
      notifyStaleItems: notifyStale,
    });
    setSettingsVisible(false);

    if (!enabled) {
      showAlert('Notifications Disabled', 'You will not receive shopping reminders for this house cart.');
    } else if (unit === 'hours') {
      showAlert('Reminder Settings Saved', `You will be reminded every ${freqHours} hour(s) before grocery runs.`);
    } else {
      showAlert('Reminder Settings Saved', `You will be reminded every ${freqDays} day(s) at ${reminderTime}.`);
    }
  };

  return (
    <View className="gap-3 mt-1">
      {/* Creative Reminder Banner (Accent-Themed) */}
      <View
        className="p-4 rounded-3xl flex-row items-center gap-3"
        style={{
          backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
          borderWidth: 1,
          borderColor: colors.border,
          elevation: 0,
          shadowOpacity: 0,
        }}
      >
        <Ionicons name="sparkles" size={18} color={colors.cyan} />
        <Text className="flex-1 text-xs font-semibold leading-snug" style={{ color: colors.textMain }}>
          {randomReminder}
        </Text>
        <TouchableOpacity
          className="p-2 rounded-full shadow-sm"
          style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
          onPress={() => {
            setEnabled(currentSettings.enabled ?? true);
            setUnit(currentSettings.frequencyUnit || 'hours');
            setFreqHours(currentSettings.frequencyHours || 6);
            setFreqDays(currentSettings.frequencyDays || 1);
            setReminderTime(currentSettings.reminderTime || '18:00');
            setNotifyStale(currentSettings.notifyStaleItems ?? true);
            setSettingsVisible(true);
          }}
        >
          <Ionicons name="settings-outline" size={15} color={colors.textSecondary} />
        </TouchableOpacity>
      </View>

      {/* Add Item Bar */}
      <View className="flex-row gap-2">
        <TextInput
          className="flex-1 h-12 rounded-2xl px-4 text-sm font-semibold shadow-sm"
          style={{
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
            color: colors.textMain,
          }}
          placeholder="Add needed item (e.g. Milk, Batteries, Bread)..."
          placeholderTextColor={colors.textSecondary}
          value={newItemTitle}
          onChangeText={setNewItemTitle}
          onSubmitEditing={handleAddItem}
        />
        <TouchableOpacity
          className="w-12 h-12 rounded-2xl items-center justify-center shadow-sm"
          style={{ backgroundColor: colors.cyan }}
          onPress={handleAddItem}
          activeOpacity={0.8}
        >
          <Ionicons name="add" size={24} color="#0F172A" />
        </TouchableOpacity>
      </View>

      {/* Checklist Items */}
      <View className="gap-2.5">
        {activeList.length === 0 ? (
          <View className="card-main items-center py-8">
            <Text className="text-sm font-semibold text-secondary">
              House cart is empty! Add items above.
            </Text>
          </View>
        ) : (
          activeList.map((item) => {
            const isDone = item.isCompleted;
            const now = Date.now();
            const createdAgeDays = (now - new Date(item.createdAt).getTime()) / 86400000;
            const isStale = !isDone && createdAgeDays >= 3;

            let expiryDaysLeft = 5;
            if (isDone && item.completedAt) {
              const elapsedDays = (now - new Date(item.completedAt).getTime()) / 86400000;
              expiryDaysLeft = Math.max(0, Math.ceil(5 - elapsedDays));
            }

            return (
              <View
                key={item.id}
                className={`card-item ${isDone ? 'opacity-60 bg-surface/50 border-surface' : 'bg-surface border-surface'}`}
              >
                <TouchableOpacity
                  className="flex-row items-center gap-3 flex-1 pr-2"
                  onPress={() => toggleListItem(item.id, cohortId)}
                >
                  <Ionicons
                    name={isDone ? 'checkbox' : 'square-outline'}
                    size={22}
                    color={isDone ? '#34D399' : isStale ? '#F59E0B' : '#94A3B8'}
                  />
                  <View className="flex-1">
                    <Text
                      className={`text-sm font-semibold text-main ${isDone ? 'line-through text-secondary' : ''}`}
                    >
                      {item.title}
                    </Text>
                    {isStale && (
                      <Text className="text-[10px] text-amber-400 font-medium mt-0.5">
                        Added {Math.floor(createdAgeDays)}d ago • Waiting to be bought
                      </Text>
                    )}
                  </View>
                </TouchableOpacity>

                <View className="flex-row items-center gap-2.5">
                  {isStale && (
                    <View className="bg-amber-500/15 px-2 py-0.5 rounded-md border border-amber-500/30">
                      <Text className="text-[10px] font-semibold text-amber-400">
                        {Math.floor(createdAgeDays)}d pending
                      </Text>
                    </View>
                  )}

                  {isDone && (
                    <View className="bg-rose-500/10 px-2 py-0.5 rounded-md border border-rose-500/20">
                      <Text className="text-[10px] font-semibold text-rose-400">
                        {expiryDaysLeft}d left
                      </Text>
                    </View>
                  )}
                  <TouchableOpacity onPress={() => deleteListItem(item.id, cohortId)}>
                    <Ionicons name="trash-outline" size={18} color="#F87171" />
                  </TouchableOpacity>
                </View>
              </View>
            );
          })
        )}
      </View>

      {/* Configurable Reminder Settings Modal */}
      <Modal visible={settingsVisible} transparent animationType="slide" onRequestClose={() => setSettingsVisible(false)}>
        <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
          <TouchableOpacity
            className="flex-1"
            activeOpacity={1}
            onPress={() => setSettingsVisible(false)}
          />
          <View className="bg-surface rounded-t-3xl p-6 gap-4 border-t border-surface max-h-[85%]">
            <View className="flex-row justify-between items-center">
              <Text className="text-lg font-bold text-main">Notification & Reminder Settings</Text>
              <TouchableOpacity onPress={() => setSettingsVisible(false)} className="p-1">
                <Ionicons name="close" size={22} color="#94A3B8" />
              </TouchableOpacity>
            </View>

            <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-4 pb-2">
              <Text className="text-xs text-secondary leading-relaxed">
                Configure personal reminders so you check the house cart before Blinkiting, Instamarting, or grocery shopping.
              </Text>

              {/* Master Enable/Disable Switch */}
              <View className="flex-row justify-between items-center py-2 border-y border-surface">
                <View className="flex-1 pr-3">
                  <Text className="text-sm font-bold text-main">Enable Reminders</Text>
                  <Text className="text-[11px] text-secondary mt-0.5">
                    {enabled ? 'Active notification schedule' : 'Muted for this cohort'}
                  </Text>
                </View>
                <Switch value={enabled} onValueChange={setEnabled} trackColor={{ true: '#38BDF8' }} />
              </View>

              {enabled && (
                <>
                  {/* Frequency Unit Selector (Hours vs Days) */}
                  <View className="gap-2">
                    <Text className="section-label">FREQUENCY TYPE</Text>
                    <View className="flex-row gap-2">
                      <TouchableOpacity
                        className={`flex-1 py-2.5 rounded-xl items-center border ${
                          unit === 'hours' ? 'bg-main border-main' : 'bg-accent-pill border-surface'
                        }`}
                        onPress={() => setUnit('hours')}
                      >
                        <Text className={`text-xs font-bold ${unit === 'hours' ? 'text-screen' : 'text-secondary'}`}>
                          Every X Hours
                        </Text>
                      </TouchableOpacity>

                      <TouchableOpacity
                        className={`flex-1 py-2.5 rounded-xl items-center border ${
                          unit === 'days' ? 'bg-main border-main' : 'bg-accent-pill border-surface'
                        }`}
                        onPress={() => setUnit('days')}
                      >
                        <Text className={`text-xs font-bold ${unit === 'days' ? 'text-screen' : 'text-secondary'}`}>
                          Every X Days
                        </Text>
                      </TouchableOpacity>
                    </View>
                  </View>

                  {/* Hours Selector */}
                  {unit === 'hours' && (
                    <View className="gap-2">
                      <View className="flex-row justify-between items-center">
                        <Text className="section-label">REPEAT EVERY</Text>
                        <Text className="text-[10px] font-bold text-sky-400">Default: 6 Hours</Text>
                      </View>
                      <View className="flex-row flex-wrap gap-2">
                        {HOUR_OPTIONS.map((h) => (
                          <TouchableOpacity
                            key={h}
                            className={`flex-1 min-w-[45px] py-2.5 rounded-xl items-center border ${
                              freqHours === h ? 'bg-main border-main' : 'bg-accent-pill border-surface'
                            }`}
                            onPress={() => setFreqHours(h)}
                          >
                            <Text
                              className={`text-xs font-bold ${
                                freqHours === h ? 'text-screen' : 'text-secondary'
                              }`}
                            >
                              {h}h
                            </Text>
                          </TouchableOpacity>
                        ))}
                      </View>
                    </View>
                  )}

                  {/* Days Selector & Time of Day */}
                  {unit === 'days' && (
                    <View className="gap-4">
                      <View className="gap-2">
                        <Text className="section-label">INTERVAL IN DAYS</Text>
                        <View className="flex-row gap-2">
                          {DAY_OPTIONS.map((d) => (
                            <TouchableOpacity
                              key={d}
                              className={`flex-1 py-2.5 rounded-xl items-center border ${
                                freqDays === d ? 'bg-main border-main' : 'bg-accent-pill border-surface'
                              }`}
                              onPress={() => setFreqDays(d)}
                            >
                              <Text
                                className={`text-xs font-bold ${
                                  freqDays === d ? 'text-screen' : 'text-secondary'
                                }`}
                              >
                                {d}d
                              </Text>
                            </TouchableOpacity>
                          ))}
                        </View>
                      </View>

                      {/* Time of Day */}
                      <View className="gap-2">
                        <Text className="section-label">NOTIFICATION TIME</Text>
                        <View className="flex-row flex-wrap gap-2">
                          {TIME_OPTIONS.map((t) => (
                            <TouchableOpacity
                              key={t.value}
                              className={`flex-1 min-w-[130px] py-2.5 px-3 rounded-xl items-center border ${
                                reminderTime === t.value ? 'bg-main border-main' : 'bg-accent-pill border-surface'
                              }`}
                              onPress={() => setReminderTime(t.value)}
                            >
                              <Text
                                className={`text-xs font-bold ${
                                  reminderTime === t.value ? 'text-screen' : 'text-secondary'
                                }`}
                              >
                                {t.label}
                              </Text>
                            </TouchableOpacity>
                          ))}
                        </View>
                      </View>
                    </View>
                  )}

                  {/* 3+ Days Stale Item Alerts Toggle */}
                  <View className="flex-row justify-between items-center py-2.5 px-3 bg-accent-pill rounded-2xl border border-surface">
                    <View className="flex-1 pr-3">
                      <Text className="text-xs font-bold text-main">3+ Days Unbought Alert</Text>
                      <Text className="text-[10px] text-secondary mt-0.5">
                        Pop up reminders on app open and alert group when items sit unchecked for 3+ days
                      </Text>
                    </View>
                    <Switch value={notifyStale} onValueChange={setNotifyStale} trackColor={{ true: '#38BDF8' }} />
                  </View>
                </>
              )}
            </ScrollView>

            <TouchableOpacity
              className="bg-main py-3.5 rounded-2xl items-center shadow-sm"
              onPress={handleSaveSettings}
            >
              <Text className="text-screen font-bold text-sm">Save Preferences</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

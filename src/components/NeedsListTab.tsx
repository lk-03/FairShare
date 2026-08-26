import React, { useState, useMemo } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
  Modal,
  Switch,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { SharedListItem, PersonalReminderSettings } from '@/types';
import { Text } from '@/components/ui/Text';

interface NeedsListTabProps {
  cohortId: string;
}

const CREATIVE_REMINDERS = [
  '🛒 Check the list before Blinkiting, BigBasketing, or Instamarting!',
  '⚡ Don\'t double-order! Review house needs before checkout.',
  '📦 Someone might have added eggs or milk—peek at the list first!',
  '🛒 Buying groceries? Tap off checked items to keep the house synced.',
  '🏠 Household Hero Alert: Check the Cart of the House list now!',
];

export function NeedsListTab({ cohortId }: NeedsListTabProps) {
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
    frequencyDays: 2,
    reminderTime: '18:00',
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

  const [freqDays, setFreqDays] = useState(currentSettings.frequencyDays);
  const [enabled, setEnabled] = useState(currentSettings.enabled);

  const handleSaveSettings = () => {
    updateReminderSettings(cohortId, {
      enabled,
      frequencyDays: freqDays,
      reminderTime: currentSettings.reminderTime,
    });
    setSettingsVisible(false);
    Alert.alert('Personal Reminders Saved', `You will be reminded every ${freqDays} day(s) before grocery runs!`);
  };

  return (
    <View className="gap-3 mt-1">
      {/* Creative Reminder Banner */}
      <View className="card-main p-4 flex-row items-center gap-3 bg-indigo-50/50 border-indigo-100">
        <Ionicons name="sparkles" size={20} color="#4F46E5" />
        <Text className="flex-1 text-xs font-semibold text-slate-700 leading-snug">
          {randomReminder}
        </Text>
        <TouchableOpacity
          className="p-1.5 rounded-full bg-white border border-indigo-100"
          onPress={() => setSettingsVisible(true)}
        >
          <Ionicons name="settings-outline" size={16} color="#4F46E5" />
        </TouchableOpacity>
      </View>

      {/* Add Item Bar */}
      <View className="flex-row gap-2">
        <TextInput
          className="flex-1 h-12 bg-white border border-slate-200 rounded-2xl px-4 text-sm text-slate-900 shadow-sm"
          placeholder="Add needed item (e.g. Milk, Batteries, Bread)..."
          placeholderTextColor="#94A3B8"
          value={newItemTitle}
          onChangeText={setNewItemTitle}
          onSubmitEditing={handleAddItem}
        />
        <TouchableOpacity
          className="w-12 h-12 rounded-2xl bg-slate-900 items-center justify-center shadow-sm"
          onPress={handleAddItem}
        >
          <Ionicons name="add" size={24} color="#FFFFFF" />
        </TouchableOpacity>
      </View>

      {/* Checklist Items */}
      <View className="gap-2.5">
        {activeList.length === 0 ? (
          <View className="card-main items-center py-8">
            <Text className="text-sm font-semibold text-slate-500">
              🛒 House cart is empty! Add items above.
            </Text>
          </View>
        ) : (
          activeList.map((item) => {
            const isDone = item.isCompleted;
            let expiryDaysLeft = 5;
            if (isDone && item.completedAt) {
              const elapsedDays = (Date.now() - new Date(item.completedAt).getTime()) / 86400000;
              expiryDaysLeft = Math.max(0, Math.ceil(5 - elapsedDays));
            }

            return (
              <View
                key={item.id}
                className={`card-item ${isDone ? 'opacity-60 bg-slate-50' : 'bg-white'}`}
              >
                <TouchableOpacity
                  className="flex-row items-center gap-3 flex-1 pr-2"
                  onPress={() => toggleListItem(item.id, cohortId)}
                >
                  <Ionicons
                    name={isDone ? 'checkbox' : 'square-outline'}
                    size={22}
                    color={isDone ? '#10B981' : '#94A3B8'}
                  />
                  <Text
                    className={`text-sm font-semibold text-slate-900 flex-1 ${isDone ? 'line-through text-slate-400' : ''}`}
                  >
                    {item.title}
                  </Text>
                </TouchableOpacity>

                <View className="flex-row items-center gap-3">
                  {isDone && (
                    <View className="bg-rose-50 px-2 py-0.5 rounded-md border border-rose-100">
                      <Text className="text-[10px] font-bold text-rose-600">
                        {expiryDaysLeft}d left
                      </Text>
                    </View>
                  )}
                  <TouchableOpacity onPress={() => deleteListItem(item.id, cohortId)}>
                    <Ionicons name="trash-outline" size={18} color="#EF4444" />
                  </TouchableOpacity>
                </View>
              </View>
            );
          })
        )}
      </View>

      {/* Personal Reminder Settings Modal */}
      <Modal visible={settingsVisible} transparent animationType="slide" onRequestClose={() => setSettingsVisible(false)}>
        <View className="flex-1 bg-black/50 justify-end">
          <View className="bg-white rounded-t-3xl p-6 gap-4 border-t border-slate-200">
            <View className="flex-row justify-between items-center">
              <Text className="text-lg font-bold text-slate-900">Personal Reminder Settings</Text>
              <TouchableOpacity onPress={() => setSettingsVisible(false)}>
                <Text className="text-xl font-bold text-slate-400 p-1">✕</Text>
              </TouchableOpacity>
            </View>

            <Text className="text-xs text-slate-500 leading-relaxed">
              These notification reminders are personal to you and remind you to check the house list before shopping on Blinkit, BigBasket, or Instamart.
            </Text>

            <View className="flex-row justify-between items-center py-2 border-y border-slate-100">
              <Text className="text-sm font-bold text-slate-900">Enable Reminders</Text>
              <Switch value={enabled} onValueChange={setEnabled} trackColor={{ true: '#0F172A' }} />
            </View>

            {enabled && (
              <>
                <Text className="section-label mt-1">REMINDER FREQUENCY</Text>
                <View className="flex-row gap-2">
                  {[1, 2, 3, 5, 7].map((d) => (
                    <TouchableOpacity
                      key={d}
                      className={`flex-1 py-2.5 rounded-xl items-center border ${
                        freqDays === d ? 'bg-slate-900 border-slate-900' : 'bg-slate-50 border-slate-200'
                      }`}
                      onPress={() => setFreqDays(d)}
                    >
                      <Text
                        className={`text-xs font-bold ${
                          freqDays === d ? 'text-white' : 'text-slate-700'
                        }`}
                      >
                        {d}d
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}

            <TouchableOpacity
              className="bg-slate-900 py-3.5 rounded-2xl items-center mt-3"
              onPress={handleSaveSettings}
            >
              <Text className="text-white font-bold text-sm">Save Personal Settings</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

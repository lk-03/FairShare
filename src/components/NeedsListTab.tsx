import React, { useState, useMemo } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  Modal,
  Switch,
  Alert,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { SharedListItem, PersonalReminderSettings } from '@/types';

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
  const theme = useTheme();
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
    <View style={styles.container}>
      {/* Creative Reminder Banner */}
      <View style={[styles.reminderBanner, { backgroundColor: 'rgba(99, 102, 241, 0.12)' }]}>
        <Ionicons name="sparkles" size={18} color="#6366F1" />
        <Text style={[styles.reminderText, { color: theme.text }]}>
          {randomReminder}
        </Text>
        <TouchableOpacity style={styles.settingsBtn} onPress={() => setSettingsVisible(true)}>
          <Ionicons name="settings-outline" size={18} color={theme.text} />
        </TouchableOpacity>
      </View>

      {/* Add Item Bar */}
      <View style={styles.addBar}>
        <TextInput
          style={[styles.addInput, { backgroundColor: theme.backgroundElement, color: theme.text }]}
          placeholder="Add needed item (e.g. Milk, Batteries, Bread)..."
          placeholderTextColor={theme.textSecondary}
          value={newItemTitle}
          onChangeText={setNewItemTitle}
          onSubmitEditing={handleAddItem}
        />
        <TouchableOpacity style={styles.addBtn} onPress={handleAddItem}>
          <Ionicons name="add" size={22} color="#FFFFFF" />
        </TouchableOpacity>
      </View>

      {/* Checklist Items */}
      <View style={styles.listContainer}>
        {activeList.length === 0 ? (
          <View style={[styles.emptyBox, { backgroundColor: theme.backgroundElement }]}>
            <Text style={[styles.emptyText, { color: theme.textSecondary }]}>
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
                style={[
                  styles.itemRow,
                  { backgroundColor: theme.backgroundElement, opacity: isDone ? 0.7 : 1 },
                ]}
              >
                <TouchableOpacity
                  style={styles.checkboxTouch}
                  onPress={() => toggleListItem(item.id, cohortId)}
                >
                  <Ionicons
                    name={isDone ? 'checkbox' : 'square-outline'}
                    size={22}
                    color={isDone ? '#10B981' : theme.textSecondary}
                  />
                  <Text
                    style={[
                      styles.itemTitle,
                      { color: theme.text },
                      isDone && styles.itemTitleDone,
                    ]}
                  >
                    {item.title}
                  </Text>
                </TouchableOpacity>

                <View style={styles.itemRight}>
                  {isDone && (
                    <View style={styles.expiryBadge}>
                      <Text style={styles.expiryBadgeText}>
                        Auto-deletes in {expiryDaysLeft}d
                      </Text>
                    </View>
                  )}
                  <TouchableOpacity onPress={() => deleteListItem(item.id, cohortId)}>
                    <Ionicons name="trash-outline" size={16} color="#EF4444" />
                  </TouchableOpacity>
                </View>
              </View>
            );
          })
        )}
      </View>

      {/* Personal Reminder Settings Modal */}
      <Modal visible={settingsVisible} transparent animationType="slide" onRequestClose={() => setSettingsVisible(false)}>
        <View style={styles.modalBackdrop}>
          <View style={[styles.modalCard, { backgroundColor: theme.backgroundElement }]}>
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: theme.text }]}>Personal Reminder Settings</Text>
              <TouchableOpacity onPress={() => setSettingsVisible(false)}>
                <Text style={[styles.closeX, { color: theme.textSecondary }]}>✕</Text>
              </TouchableOpacity>
            </View>

            <Text style={[styles.settingDesc, { color: theme.textSecondary }]}>
              These notification reminders are personal to you and remind you to check the house list before shopping on Blinkit, BigBasket, or Instamart.
            </Text>

            <View style={styles.settingRow}>
              <Text style={[styles.settingLabel, { color: theme.text }]}>Enable Reminders</Text>
              <Switch value={enabled} onValueChange={setEnabled} trackColor={{ true: '#6366F1' }} />
            </View>

            {enabled && (
              <>
                <Text style={[styles.label, { color: theme.textSecondary }]}>REMINDER FREQUENCY</Text>
                <View style={styles.freqRow}>
                  {[1, 2, 3, 5, 7].map((d) => (
                    <TouchableOpacity
                      key={d}
                      style={[
                        styles.freqBtn,
                        freqDays === d ? styles.freqBtnActive : { backgroundColor: theme.backgroundSelected },
                      ]}
                      onPress={() => setFreqDays(d)}
                    >
                      <Text
                        style={[
                          styles.freqText,
                          freqDays === d ? styles.freqTextActive : { color: theme.text },
                        ]}
                      >
                        Every {d}d
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </>
            )}

            <TouchableOpacity style={styles.saveSettingsBtn} onPress={handleSaveSettings}>
              <Text style={styles.saveSettingsText}>Save Personal Settings</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 12,
    marginTop: 4,
  },
  reminderBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    borderRadius: 14,
    gap: 10,
  },
  reminderText: {
    flex: 1,
    fontSize: 12,
    fontWeight: '600',
  },
  settingsBtn: {
    padding: 4,
  },
  addBar: {
    flexDirection: 'row',
    gap: 8,
  },
  addInput: {
    flex: 1,
    height: 44,
    borderRadius: 12,
    paddingHorizontal: 14,
    fontSize: 14,
  },
  addBtn: {
    width: 44,
    height: 44,
    borderRadius: 12,
    backgroundColor: '#6366F1',
    alignItems: 'center',
    justifyContent: 'center',
  },
  listContainer: {
    gap: 8,
  },
  emptyBox: {
    padding: 24,
    borderRadius: 14,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 13,
    fontWeight: '600',
  },
  itemRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 14,
    borderRadius: 12,
  },
  checkboxTouch: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
  },
  itemTitle: {
    fontSize: 14,
    fontWeight: '600',
  },
  itemTitleDone: {
    textDecorationLine: 'line-through',
    opacity: 0.6,
  },
  itemRight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  expiryBadge: {
    backgroundColor: 'rgba(239, 68, 68, 0.12)',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
  },
  expiryBadgeText: {
    color: '#EF4444',
    fontSize: 10,
    fontWeight: '700',
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'flex-end',
  },
  modalCard: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 20,
    gap: 16,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '800',
  },
  closeX: {
    fontSize: 18,
    fontWeight: '700',
    padding: 4,
  },
  settingDesc: {
    fontSize: 13,
  },
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  settingLabel: {
    fontSize: 15,
    fontWeight: '600',
  },
  label: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.5,
  },
  freqRow: {
    flexDirection: 'row',
    gap: 6,
  },
  freqBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
  },
  freqBtnActive: {
    backgroundColor: '#6366F1',
  },
  freqText: {
    fontSize: 12,
    fontWeight: '700',
  },
  freqTextActive: {
    color: '#FFFFFF',
  },
  saveSettingsBtn: {
    backgroundColor: '#6366F1',
    paddingVertical: 14,
    borderRadius: 12,
    alignItems: 'center',
    marginTop: 8,
  },
  saveSettingsText: {
    color: '#FFFFFF',
    fontWeight: '800',
    fontSize: 15,
  },
});

import React, { useState, useMemo } from 'react';
import { View, Modal, TouchableOpacity, ScrollView, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { Text } from '@/components/ui/Text';

export function StaleNeedsReminderModal() {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);

  const { sharedLists, cohorts, currentUser, toggleListItem } = useExpenseStore();
  const [dismissed, setDismissed] = useState(false);

  // Find all unbought items older than 3 days (3 * 86400000 ms)
  const staleItems = useMemo(() => {
    const THREE_DAYS_MS = 3 * 86400000;
    const now = Date.now();
    const list: {
      id: string;
      cohortId: string;
      cohortName: string;
      title: string;
      daysOld: number;
      isMine: boolean;
    }[] = [];

    const cohortMap = new Map(cohorts.map((c) => [c.id, c.name]));

    Object.entries(sharedLists).forEach(([cohortId, items]) => {
      items.forEach((item) => {
        if (!item.isCompleted) {
          const age = now - new Date(item.createdAt).getTime();
          if (age >= THREE_DAYS_MS) {
            list.push({
              id: item.id,
              cohortId,
              cohortName: cohortMap.get(cohortId) || 'Group',
              title: item.title,
              daysOld: Math.floor(age / 86400000),
              isMine: item.addedByUserId === currentUser.id,
            });
          }
        }
      });
    });

    return list;
  }, [sharedLists, cohorts, currentUser]);

  const visible = !dismissed && staleItems.length > 0;

  if (!visible) return null;

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={() => setDismissed(true)}>
      <View className={`flex-1 ${activeThemeClass} bg-black/60 items-center justify-center px-5`}>
        <View className="w-full max-w-md bg-surface rounded-3xl p-6 border border-surface shadow-2xl gap-4">
          {/* Header Icon + Title */}
          <View className="flex-row items-start gap-3.5">
            <View className="w-10 h-10 rounded-2xl bg-amber-500/15 border border-amber-500/30 items-center justify-center">
              <Ionicons name="time-outline" size={22} color="#F59E0B" />
            </View>
            <View className="flex-1">
              <Text className="text-lg font-bold text-main">Pending House Needs</Text>
              <Text className="text-xs text-secondary mt-0.5 leading-snug">
                The following items were added 3+ days ago and are still waiting to be bought or updated:
              </Text>
            </View>
          </View>

          {/* Stale Items Scroll List */}
          <ScrollView className="max-h-56 gap-2 my-1" showsVerticalScrollIndicator={false}>
            {staleItems.map((item) => (
              <View
                key={item.id}
                className="flex-row items-center justify-between p-3 rounded-2xl bg-accent-pill border border-surface mb-2"
              >
                <View className="flex-1 pr-3">
                  <Text className="text-sm font-bold text-main" numberOfLines={1}>
                    {item.title}
                  </Text>
                  <Text className="text-[11px] text-secondary mt-0.5" numberOfLines={1}>
                    {item.cohortName} • Added {item.daysOld}d ago {item.isMine ? '(by You)' : ''}
                  </Text>
                </View>

                <TouchableOpacity
                  className="bg-emerald-500/15 border border-emerald-500/30 px-3 py-1.5 rounded-xl flex-row items-center gap-1.5"
                  onPress={() => toggleListItem(item.id, item.cohortId)}
                >
                  <Ionicons name="checkmark" size={14} color="#34D399" />
                  <Text className="text-xs font-semibold text-emerald-400">Bought</Text>
                </TouchableOpacity>
              </View>
            ))}
          </ScrollView>

          {/* Action CTAs */}
          <View className="flex-row gap-3 pt-2 border-t border-surface">
            <TouchableOpacity
              className="flex-1 bg-main py-3.5 rounded-2xl items-center shadow-sm"
              onPress={() => setDismissed(true)}
            >
              <Text className="text-screen font-bold text-sm">Got it / Dismiss</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

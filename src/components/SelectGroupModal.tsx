import React from 'react';
import { View, Modal, TouchableOpacity, ScrollView, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { EventCohort } from '@/types';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { Text } from '@/components/ui/Text';

interface SelectGroupModalProps {
  visible: boolean;
  onClose: () => void;
  onSelectGroup: (cohort: EventCohort) => void;
  onCreateNewGroup?: () => void;
}

export function SelectGroupModal({
  visible,
  onClose,
  onSelectGroup,
  onCreateNewGroup,
}: SelectGroupModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);

  const { cohorts, members } = useExpenseStore();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <View className={`flex-1 ${activeThemeClass} bg-black/50 justify-end`}>
        <TouchableOpacity
          className="flex-1"
          activeOpacity={1}
          onPress={onClose}
        />
        <View className="bg-surface rounded-t-3xl p-6 border-t border-surface max-h-[80%]">
          {/* Header */}
          <View className="flex-row justify-between items-center mb-2">
            <View>
              <Text className="text-xl font-extrabold text-main">Select Group</Text>
              <Text className="text-xs text-secondary mt-0.5">Which group is this expense for?</Text>
            </View>
            <TouchableOpacity
              onPress={onClose}
              className="w-9 h-9 rounded-full bg-accent-pill items-center justify-center border border-surface"
            >
              <Ionicons name="close" size={20} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          {/* Group List */}
          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerClassName="gap-3 py-4"
          >
            {cohorts.map((cohort) => {
              const count = (members[cohort.id] || []).length;
              return (
                <TouchableOpacity
                  key={cohort.id}
                  activeOpacity={0.7}
                  className="flex-row items-center justify-between p-4 bg-accent-pill border border-surface rounded-2xl"
                  onPress={() => onSelectGroup(cohort)}
                >
                  <View className="flex-row items-center gap-3.5 flex-1 pr-3">
                    <GroupAvatar
                      avatarUrl={cohort.avatarUrl || cohort.bannerUrl}
                      category={cohort.category}
                      customIcon={cohort.customIcon}
                      size={44}
                      variant="solid"
                    />
                    <View className="flex-1">
                      <Text className="font-bold text-main text-base" numberOfLines={1}>
                        {cohort.name}
                      </Text>
                      <Text className="text-xs text-secondary mt-0.5">
                        {count} {count === 1 ? 'member' : 'members'} • {cohort.currency || 'INR'}
                      </Text>
                    </View>
                  </View>
                  <Ionicons name="chevron-forward" size={20} color="#94A3B8" />
                </TouchableOpacity>
              );
            })}

            {onCreateNewGroup && (
              <TouchableOpacity
                activeOpacity={0.7}
                className="flex-row items-center justify-center p-4 bg-surface border border-dashed border-surface rounded-2xl mt-2 gap-2"
                onPress={() => {
                  onClose();
                  onCreateNewGroup();
                }}
              >
                <Ionicons name="add-circle-outline" size={20} color="#38BDF8" />
                <Text className="text-sm font-bold text-sky-400">Create New Group</Text>
              </TouchableOpacity>
            )}
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

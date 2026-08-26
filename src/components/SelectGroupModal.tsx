import React from 'react';
import { View, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { EventCohort } from '@/types';
import { CategoryIcon } from '@/components/ui/CategoryIcon';
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
  const { cohorts, members } = useExpenseStore();

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
    >
      <TouchableOpacity
        className="flex-1 bg-black/50 justify-end"
        activeOpacity={1}
        onPress={onClose}
      >
        <TouchableOpacity
          activeOpacity={1}
          className="bg-white rounded-t-3xl p-6 border-t border-slate-200 max-h-[80%]"
        >
          {/* Header */}
          <View className="flex-row justify-between items-center mb-2">
            <View>
              <Text className="text-xl font-extrabold text-slate-900">Select Group</Text>
              <Text className="text-xs text-slate-500 mt-0.5">Which group is this expense for?</Text>
            </View>
            <TouchableOpacity
              onPress={onClose}
              className="w-9 h-9 rounded-full bg-slate-100 items-center justify-center border border-slate-200"
            >
              <Ionicons name="close" size={20} color="#64748B" />
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
                  className="flex-row items-center justify-between p-4 bg-slate-50 border border-slate-200 rounded-2xl active:bg-slate-100"
                  onPress={() => onSelectGroup(cohort)}
                >
                  <View className="flex-row items-center gap-3.5 flex-1 pr-3">
                    <CategoryIcon
                      category={cohort.category}
                      customIcon={cohort.customIcon}
                      size={44}
                      variant="solid"
                    />
                    <View className="flex-1">
                      <Text className="font-bold text-slate-900 text-base" numberOfLines={1}>
                        {cohort.name}
                      </Text>
                      <Text className="text-xs text-slate-500 mt-0.5">
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
                className="flex-row items-center justify-center p-4 bg-white border border-dashed border-slate-300 rounded-2xl mt-2 gap-2"
                onPress={() => {
                  onClose();
                  onCreateNewGroup();
                }}
              >
                <Ionicons name="add-circle-outline" size={20} color="#2563EB" />
                <Text className="text-sm font-bold text-blue-600">Create New Group</Text>
              </TouchableOpacity>
            )}
          </ScrollView>
        </TouchableOpacity>
      </TouchableOpacity>
    </Modal>
  );
}

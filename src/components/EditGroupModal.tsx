import React, { useState, useEffect } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import { useExpenseStore } from '@/store/useExpenseStore';
import { EventCategory, EventCohort } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface EditGroupModalProps {
  visible: boolean;
  onClose: () => void;
  cohort: EventCohort;
}

export function EditGroupModal({ visible, onClose, cohort }: EditGroupModalProps) {
  const { updateCohort } = useExpenseStore();

  const [name, setName] = useState(cohort.name);
  const [description, setDescription] = useState(cohort.description || '');
  const [category, setCategory] = useState<EventCategory>(cohort.category);
  const [customCategoryName, setCustomCategoryName] = useState('');
  const [customIcon, setCustomIcon] = useState(cohort.customIcon || 'gift');

  useEffect(() => {
    setName(cohort.name);
    setDescription(cohort.description || '');
    setCategory(cohort.category);
    setCustomIcon(cohort.customIcon || 'gift');
  }, [cohort, visible]);

  const categories: { label: string; value: EventCategory }[] = [
    { label: 'Trip', value: 'trip' },
    { label: 'House', value: 'house' },
    { label: 'Event', value: 'event' },
    { label: 'Dining', value: 'dining' },
    { label: 'Transport', value: 'transport' },
    { label: 'Utilities', value: 'utilities' },
    { label: 'Custom', value: 'custom' },
  ];

  const handleSave = () => {
    if (!name.trim()) {
      Alert.alert('Name Required', 'Please enter a group or event name.');
      return;
    }

    const finalCategory = category === 'custom' && customCategoryName.trim() ? customCategoryName.trim() : category;

    updateCohort(cohort.id, {
      name: name.trim(),
      description: description.trim() || undefined,
      category: finalCategory as EventCategory,
      customIcon: category === 'custom' ? customIcon : undefined,
    });

    onClose();
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <TouchableOpacity className="flex-1 bg-black/50 justify-end" activeOpacity={1} onPress={onClose}>
        <TouchableOpacity activeOpacity={1} className="bg-white rounded-t-3xl max-h-[90%] p-6 border-t border-slate-200">
          {/* Header */}
          <View className="flex-row justify-between items-center mb-4">
            <Text className="text-xl font-extrabold text-slate-900">Edit Group Info</Text>
            <TouchableOpacity onPress={onClose}>
              <Text className="text-xl font-bold text-slate-400 p-1">✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-3 pb-8">
            {/* Event Name */}
            <Text className="section-label">EVENT / GROUP NAME</Text>
            <TextInput
              className="h-12 bg-white border border-slate-200 rounded-2xl px-4 text-sm text-slate-900 shadow-sm"
              placeholder="Group name"
              placeholderTextColor="#94A3B8"
              value={name}
              onChangeText={setName}
            />

            {/* Description */}
            <Text className="section-label">DESCRIPTION</Text>
            <TextInput
              className="h-12 bg-white border border-slate-200 rounded-2xl px-4 text-sm text-slate-900 shadow-sm"
              placeholder="Description"
              placeholderTextColor="#94A3B8"
              value={description}
              onChangeText={setDescription}
            />

            {/* Category Selector */}
            <Text className="section-label">CATEGORY</Text>
            <View className="flex-row flex-wrap gap-2">
              {categories.map((cat) => {
                const isSelected = category === cat.value;
                return (
                  <TouchableOpacity
                    key={cat.value}
                    className={`flex-row items-center gap-2 px-3 py-2 rounded-2xl border ${
                      isSelected ? 'bg-slate-900 border-slate-900' : 'bg-slate-50 border-slate-200'
                    }`}
                    onPress={() => setCategory(cat.value)}
                  >
                    <CategoryIcon category={cat.value} customIcon={customIcon} size={24} variant={isSelected ? 'solid' : 'light'} />
                    <Text
                      className={`text-xs font-bold ${
                        isSelected ? 'text-white' : 'text-slate-700'
                      }`}
                    >
                      {cat.label}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>

            {/* Custom Icon Picker Grid */}
            {category === 'custom' && (
              <View className="p-3 bg-slate-50 border border-slate-200 rounded-2xl gap-2 mt-1">
                <Text className="text-xs font-bold text-slate-700">Custom Category Name:</Text>
                <TextInput
                  className="h-10 bg-white border border-slate-200 rounded-xl px-3 text-xs text-slate-900"
                  placeholder="e.g. Badminton, Movie Night"
                  placeholderTextColor="#94A3B8"
                  value={customCategoryName}
                  onChangeText={setCustomCategoryName}
                />

                <Text className="text-xs font-bold text-slate-700 mt-1">Choose Custom Icon:</Text>
                <View className="flex-row flex-wrap gap-2">
                  {GENERIC_CUSTOM_ICONS.map((item) => {
                    const isSelected = customIcon === item.name;
                    return (
                      <TouchableOpacity
                        key={item.name}
                        className={`items-center justify-center w-14 h-12 rounded-xl border ${
                          isSelected ? 'bg-slate-900 border-slate-900' : 'bg-white border-slate-200'
                        }`}
                        onPress={() => setCustomIcon(item.name)}
                      >
                        <Ionicons
                          name={item.name}
                          size={18}
                          color={isSelected ? '#FFFFFF' : '#475569'}
                        />
                        <Text
                          className={`text-[9px] font-semibold mt-0.5 ${
                            isSelected ? 'text-white' : 'text-slate-500'
                          }`}
                        >
                          {item.label}
                        </Text>
                      </TouchableOpacity>
                    );
                  })}
                </View>
              </View>
            )}

            {/* Submit Button */}
            <TouchableOpacity
              className="bg-slate-900 py-4 rounded-2xl items-center mt-3 shadow-sm"
              onPress={handleSave}
            >
              <Text className="text-white font-bold text-base">Save Changes</Text>
            </TouchableOpacity>
          </ScrollView>
        </TouchableOpacity>
      </TouchableOpacity>
    </Modal>
  );
}

import React, { useState } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { EventCategory, EventCohort } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface CreateGroupModalProps {
  visible: boolean;
  onClose: () => void;
}

export function CreateGroupModal({ visible, onClose }: CreateGroupModalProps) {
  const router = useRouter();
  const { addCohort, currentUser } = useExpenseStore();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState<EventCategory>('trip');
  const [customCategoryName, setCustomCategoryName] = useState('');
  const [customIcon, setCustomIcon] = useState('gift');
  const [currency, setCurrency] = useState('INR');

  const categories: { label: string; value: EventCategory }[] = [
    { label: 'Trip', value: 'trip' },
    { label: 'House', value: 'house' },
    { label: 'Event', value: 'event' },
    { label: 'Dining', value: 'dining' },
    { label: 'Transport', value: 'transport' },
    { label: 'Utilities', value: 'utilities' },
    { label: 'Custom', value: 'custom' },
  ];

  const handleCreate = () => {
    if (!name.trim()) {
      Alert.alert('Name Required', 'Please enter a group or event name.');
      return;
    }

    const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    const cleanNameCode = name.replace(/[^a-zA-Z0-9]/g, '').substring(0, 4).toUpperCase();
    const inviteCode = `${cleanNameCode || 'FS'}${randomSuffix}`;

    const newCohort: EventCohort = {
      id: `cohort_${Date.now()}`,
      name: name.trim(),
      description: description.trim() || undefined,
      category,
      customIcon: category === 'custom' ? customIcon : undefined,
      currency,
      createdBy: currentUser.id,
      inviteCode,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    addCohort(newCohort);
    onClose();
    resetForm();

    // Navigate to the newly created cohort screen
    router.push(`/event/${newCohort.id}` as any);
  };

  const resetForm = () => {
    setName('');
    setDescription('');
    setCategory('trip');
    setCustomIcon('gift');
    setCurrency('INR');
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <TouchableOpacity className="flex-1 bg-black/50 justify-end" activeOpacity={1} onPress={onClose}>
        <TouchableOpacity activeOpacity={1} className="bg-white rounded-t-3xl max-h-[90%] p-6 border-t border-slate-200">
          {/* Header */}
          <View className="flex-row justify-between items-center mb-4">
            <Text className="text-xl font-extrabold text-slate-900">Create Event Cohort</Text>
            <TouchableOpacity onPress={onClose}>
              <Text className="text-xl font-bold text-slate-400 p-1">✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-3 pb-8">
            {/* Event Name */}
            <Text className="section-label">EVENT / GROUP NAME</Text>
            <TextInput
              className="h-12 bg-white border border-slate-200 rounded-2xl px-4 text-sm text-slate-900 shadow-sm"
              placeholder="e.g. Goa Vacation, Apartment 402"
              placeholderTextColor="#94A3B8"
              value={name}
              onChangeText={setName}
            />

            {/* Description */}
            <Text className="section-label">DESCRIPTION (OPTIONAL)</Text>
            <TextInput
              className="h-12 bg-white border border-slate-200 rounded-2xl px-4 text-sm text-slate-900 shadow-sm"
              placeholder="Brief note or destination details"
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
                  placeholder="e.g. Badminton Club, Movie Night, Snacks"
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

            {/* Currency Selector */}
            <Text className="section-label">CURRENCY</Text>
            <View className="flex-row gap-2">
              {['INR', 'USD', 'EUR', 'GBP'].map((curr) => (
                <TouchableOpacity
                  key={curr}
                  className={`flex-1 py-2.5 rounded-xl items-center border ${
                    currency === curr ? 'bg-slate-900 border-slate-900' : 'bg-slate-50 border-slate-200'
                  }`}
                  onPress={() => setCurrency(curr)}
                >
                  <Text
                    className={`text-xs font-bold ${
                      currency === curr ? 'text-white' : 'text-slate-700'
                    }`}
                  >
                    {curr}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Submit Button */}
            <TouchableOpacity
              className="bg-slate-900 py-4 rounded-2xl items-center mt-3 shadow-sm"
              onPress={handleCreate}
            >
              <Text className="text-white font-bold text-base">Create Cohort Ledger</Text>
            </TouchableOpacity>
          </ScrollView>
        </TouchableOpacity>
      </TouchableOpacity>
    </Modal>
  );
}

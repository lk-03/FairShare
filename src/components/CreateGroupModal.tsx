import React, { useState } from 'react';
import {
  View,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  useColorScheme,
} from 'react-native';
import { useRouter } from 'expo-router';
import * as ImagePicker from 'expo-image-picker';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { EventCategory, EventCohort } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { GroupAvatar } from '@/components/ui/GroupAvatar';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

interface CreateGroupModalProps {
  visible: boolean;
  onClose: () => void;
}

export function CreateGroupModal({ visible, onClose }: CreateGroupModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);

  const router = useRouter();
  const { addCohort, currentUser } = useExpenseStore();

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [category, setCategory] = useState<EventCategory>('house');
  const [currency, setCurrency] = useState('INR');
  const [avatarUrl, setAvatarUrl] = useState<string | undefined>();
  const [customCategoryName, setCustomCategoryName] = useState('');
  const [customIcon, setCustomIcon] = useState('shapes-outline');

  const categories: { label: string; value: EventCategory }[] = [
    { label: 'House / Roommates', value: 'house' },
    { label: 'Trip / Travel', value: 'trip' },
    { label: 'Event', value: 'event' },
    { label: 'Dining', value: 'dining' },
    { label: 'Transport', value: 'transport' },
    { label: 'Utilities', value: 'utilities' },
    { label: 'Custom', value: 'custom' },
  ];

  const handlePickImage = async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        showAlert(
          'Permission Denied',
          'Camera roll access is needed to select a group profile picture.'
        );
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ['images'],
        allowsEditing: true,
        aspect: [1, 1],
        quality: 0.8,
      });

      if (!result.canceled && result.assets[0]?.uri) {
        setAvatarUrl(result.assets[0].uri);
      }
    } catch (e) {
      console.warn('Image picker error:', e);
    }
  };

  const handleCreate = async () => {
    if (!name.trim()) {
      showAlert('Name Required', 'Please enter a group or event name.');
      return;
    }

    const randomSuffix = Math.random().toString(36).substring(2, 6).toUpperCase();
    const cleanNameCode = name.replace(/[^a-zA-Z0-9]/g, '').substring(0, 4).toUpperCase();
    const inviteCode = `${cleanNameCode || 'FS'}${randomSuffix}`;

    const isCustom = category === 'custom';
    const finalCategory: EventCategory = isCustom
      ? (customCategoryName.trim() ? (customCategoryName.trim().toLowerCase() as EventCategory) : 'custom')
      : category;

    const newCohort: EventCohort = {
      id: `cohort_${Date.now()}`,
      name: name.trim(),
      description: description.trim() || undefined,
      category: finalCategory,
      customIcon: isCustom ? customIcon : undefined,
      avatarUrl: avatarUrl || undefined,
      currency,
      createdBy: currentUser.id,
      inviteCode,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    const saved = await addCohort(newCohort);
    onClose();
    resetForm();

    // Navigate to the newly created cohort screen
    router.push(`/event/${saved.id}` as any);
  };

  const resetForm = () => {
    setName('');
    setDescription('');
    setCategory('trip');
    setCustomIcon('gift');
    setCurrency('INR');
    setAvatarUrl(undefined);
  };

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/50 justify-end`}>
        <TouchableOpacity
          className="flex-1"
          activeOpacity={1}
          onPress={onClose}
        />
        <View className="bg-surface rounded-t-3xl max-h-[90%] p-6 border-t border-surface">
          {/* Header */}
          <View className="flex-row justify-between items-center mb-3">
            <Text className="text-xl font-extrabold text-main">Create Event Cohort</Text>
            <TouchableOpacity onPress={onClose} className="p-1">
              <Ionicons name="close" size={22} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-3 pb-8">
            {/* Group Profile Picture Picker */}
            <View className="items-center justify-center my-1">
              <View className="relative">
                <GroupAvatar
                  avatarUrl={avatarUrl}
                  category={category}
                  customIcon={category === 'custom' ? customIcon : undefined}
                  size={76}
                  variant="solid"
                />
                <TouchableOpacity
                  activeOpacity={0.8}
                  className="absolute -bottom-1 -right-1 w-7 h-7 rounded-full bg-main items-center justify-center border-2 border-surface shadow-sm"
                  onPress={handlePickImage}
                >
                  <Ionicons name="camera" size={13} color="#0F172A" />
                </TouchableOpacity>
              </View>

              <View className="flex-row items-center gap-2.5 mt-2.5">
                <TouchableOpacity
                  onPress={handlePickImage}
                  className="px-3.5 py-1.5 rounded-full bg-accent-pill border border-surface flex-row items-center gap-1.5"
                >
                  <Ionicons name="image-outline" size={13} color="#94A3B8" />
                  <Text className="text-xs font-semibold text-main">
                    {avatarUrl ? 'Change Picture' : '+ Add Picture'}
                  </Text>
                </TouchableOpacity>
                {avatarUrl && (
                  <TouchableOpacity
                    onPress={() => setAvatarUrl(undefined)}
                    className="px-3 py-1.5 rounded-full bg-rose-500/10 border border-rose-500/20"
                  >
                    <Text className="text-xs font-semibold text-rose-400">Remove</Text>
                  </TouchableOpacity>
                )}
              </View>
            </View>

            {/* Event Name */}
            <Text className="section-label">EVENT / GROUP NAME</Text>
            <TextInput
              className="h-12 bg-surface border border-surface rounded-2xl px-4 text-sm text-main shadow-sm"
              placeholder="e.g. Goa Vacation, Apartment 402"
              placeholderTextColor="#94A3B8"
              value={name}
              onChangeText={setName}
            />

            {/* Description */}
            <Text className="section-label">DESCRIPTION (OPTIONAL)</Text>
            <TextInput
              className="h-12 bg-surface border border-surface rounded-2xl px-4 text-sm text-main shadow-sm"
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
                    key={`${cat.value}-${isSelected}`}
                    className={`flex-row items-center gap-2 px-3.5 py-2.5 rounded-2xl border ${
                      isSelected
                        ? 'bg-main border-main'
                        : 'bg-accent-pill border-surface'
                    }`}
                    onPress={() => {
                      setCategory(cat.value);
                      if (cat.value !== 'custom') {
                        setCustomCategoryName('');
                      }
                    }}
                  >
                    <CategoryIcon
                      category={cat.value}
                      customIcon={cat.value === 'custom' ? customIcon : undefined}
                      size={24}
                      variant={isSelected ? 'solid' : 'light'}
                    />
                    <Text
                      className={`text-xs font-bold ${
                        isSelected ? 'text-screen' : 'text-secondary'
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
              <View className="p-3.5 bg-accent-pill border border-surface rounded-2xl gap-2 mt-1">
                <Text className="text-xs font-bold text-main">Custom Category Name:</Text>
                <TextInput
                  className="h-10 bg-surface border border-surface rounded-xl px-3 text-xs text-main"
                  placeholder="e.g. Badminton Club, Movie Night, Snacks"
                  placeholderTextColor="#94A3B8"
                  value={customCategoryName}
                  onChangeText={setCustomCategoryName}
                />

                <Text className="text-xs font-bold text-main mt-1">Choose Custom Icon:</Text>
                <View className="flex-row flex-wrap gap-2">
                  {GENERIC_CUSTOM_ICONS.map((item) => {
                    const isSelected = customIcon === item.name;
                    return (
                      <TouchableOpacity
                        key={item.name}
                        className={`items-center justify-center w-14 h-12 rounded-xl border ${
                          isSelected
                            ? 'bg-main border-main'
                            : 'bg-surface border-surface'
                        }`}
                        onPress={() => setCustomIcon(item.name)}
                      >
                        <Ionicons
                          name={item.name}
                          size={18}
                          color={isSelected ? '#0F172A' : '#94A3B8'}
                        />
                        <Text
                          className={`text-[9px] font-semibold mt-0.5 ${
                            isSelected ? 'text-screen font-bold' : 'text-secondary'
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
                    currency === curr
                      ? 'bg-main border-main'
                      : 'bg-accent-pill border-surface'
                  }`}
                  onPress={() => setCurrency(curr)}
                >
                  <Text
                    className={`text-xs font-bold ${
                      currency === curr ? 'text-screen' : 'text-secondary'
                    }`}
                  >
                    {curr}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Submit Button */}
            <TouchableOpacity
              className="bg-main py-4 rounded-2xl items-center mt-3 shadow-sm"
              onPress={handleCreate}
            >
              <Text className="text-screen font-bold text-base">Create Cohort Ledger</Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

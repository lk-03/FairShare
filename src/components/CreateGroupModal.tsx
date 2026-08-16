import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  Modal,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Alert,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { EventCategory, EventCohort } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';

interface CreateGroupModalProps {
  visible: boolean;
  onClose: () => void;
}

export function CreateGroupModal({ visible, onClose }: CreateGroupModalProps) {
  const theme = useTheme();
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
      <View style={styles.backdrop}>
        <View style={[styles.card, { backgroundColor: theme.backgroundElement }]}>
          {/* Header */}
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: theme.text }]}>Create Event Cohort</Text>
            <TouchableOpacity onPress={onClose}>
              <Text style={[styles.closeX, { color: theme.textSecondary }]}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.formContent}>
            {/* Event Name */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>EVENT / GROUP NAME</Text>
            <TextInput
              style={[styles.input, { backgroundColor: theme.backgroundSelected, color: theme.text }]}
              placeholder="e.g. Goa Vacation, Apartment 402"
              placeholderTextColor={theme.textSecondary}
              value={name}
              onChangeText={setName}
            />

            {/* Description */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>DESCRIPTION (OPTIONAL)</Text>
            <TextInput
              style={[styles.input, { backgroundColor: theme.backgroundSelected, color: theme.text }]}
              placeholder="Brief note or destination details"
              placeholderTextColor={theme.textSecondary}
              value={description}
              onChangeText={setDescription}
            />

            {/* Category Selector */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>CATEGORY</Text>
            <View style={styles.categoryGrid}>
              {categories.map((cat) => (
                <TouchableOpacity
                  key={cat.value}
                  style={[
                    styles.categoryBtn,
                    category === cat.value ? styles.categoryBtnActive : { backgroundColor: theme.backgroundSelected },
                  ]}
                  onPress={() => setCategory(cat.value)}
                >
                  <CategoryIcon category={cat.value} customIcon={customIcon} size={22} />
                  <Text
                    style={[
                      styles.catLabel,
                      category === cat.value ? styles.catLabelActive : { color: theme.text },
                    ]}
                  >
                    {cat.label}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Custom Icon Picker Grid */}
            {category === 'custom' && (
              <View style={styles.customPickerBox}>
                <Text style={[styles.subLabel, { color: theme.text }]}>Custom Category Name:</Text>
                <TextInput
                  style={[styles.input, { backgroundColor: theme.backgroundSelected, color: theme.text, marginBottom: 12 }]}
                  placeholder="e.g. Badminton Club, Movie Night, Snacks"
                  placeholderTextColor={theme.textSecondary}
                  value={customCategoryName}
                  onChangeText={setCustomCategoryName}
                />

                <Text style={[styles.subLabel, { color: theme.text }]}>Choose Custom Icon:</Text>
                <View style={styles.iconGrid}>
                  {GENERIC_CUSTOM_ICONS.map((item) => {
                    const isSelected = customIcon === item.name;
                    return (
                      <TouchableOpacity
                        key={item.name}
                        style={[
                          styles.iconPickTile,
                          isSelected ? styles.iconPickTileActive : { backgroundColor: theme.backgroundSelected },
                        ]}
                        onPress={() => setCustomIcon(item.name)}
                      >
                        <Ionicons
                          name={item.name}
                          size={20}
                          color={isSelected ? '#FFFFFF' : theme.text}
                        />
                        <Text
                          style={[
                            styles.iconPickText,
                            isSelected ? { color: '#FFFFFF' } : { color: theme.textSecondary },
                          ]}
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
            <Text style={[styles.label, { color: theme.textSecondary }]}>CURRENCY</Text>
            <View style={styles.currencyRow}>
              {['INR', 'USD', 'EUR', 'GBP'].map((curr) => (
                <TouchableOpacity
                  key={curr}
                  style={[
                    styles.currBtn,
                    currency === curr ? styles.currBtnActive : { backgroundColor: theme.backgroundSelected },
                  ]}
                  onPress={() => setCurrency(curr)}
                >
                  <Text
                    style={[
                      styles.currText,
                      currency === curr ? styles.currTextActive : { color: theme.text },
                    ]}
                  >
                    {curr}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* Submit Button */}
            <TouchableOpacity style={styles.createBtn} onPress={handleCreate}>
              <Text style={styles.createBtnText}>Create Cohort Ledger</Text>
            </TouchableOpacity>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    justifyContent: 'flex-end',
  },
  card: {
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    maxHeight: '90%',
    padding: 20,
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: '800',
  },
  closeX: {
    fontSize: 20,
    fontWeight: '700',
    padding: 4,
  },
  formContent: {
    gap: 12,
    paddingBottom: 24,
  },
  label: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.5,
    marginTop: 4,
  },
  subLabel: {
    fontSize: 12,
    fontWeight: '700',
    marginBottom: 8,
  },
  input: {
    height: 44,
    borderRadius: 12,
    paddingHorizontal: 14,
    fontSize: 15,
  },
  categoryGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  categoryBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
  },
  categoryBtnActive: {
    backgroundColor: '#6366F1',
  },
  catLabel: {
    fontSize: 13,
    fontWeight: '600',
  },
  catLabelActive: {
    color: '#FFFFFF',
    fontWeight: '700',
  },
  customPickerBox: {
    marginTop: 6,
    marginBottom: 4,
  },
  iconGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  iconPickTile: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 60,
    height: 52,
    borderRadius: 10,
    gap: 2,
  },
  iconPickTileActive: {
    backgroundColor: '#EC4899',
  },
  iconPickText: {
    fontSize: 10,
    fontWeight: '600',
  },
  currencyRow: {
    flexDirection: 'row',
    gap: 8,
  },
  currBtn: {
    flex: 1,
    paddingVertical: 10,
    borderRadius: 10,
    alignItems: 'center',
  },
  currBtnActive: {
    backgroundColor: '#6366F1',
  },
  currText: {
    fontSize: 13,
    fontWeight: '700',
  },
  currTextActive: {
    color: '#FFFFFF',
  },
  createBtn: {
    backgroundColor: '#6366F1',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    marginTop: 16,
  },
  createBtnText: {
    color: '#FFFFFF',
    fontWeight: '800',
    fontSize: 16,
  },
});

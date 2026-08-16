import React, { useState, useEffect } from 'react';
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
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { EventCategory, EventCohort } from '@/types';
import { CategoryIcon, GENERIC_CUSTOM_ICONS } from '@/components/ui/CategoryIcon';
import { Ionicons } from '@expo/vector-icons';

interface EditGroupModalProps {
  visible: boolean;
  onClose: () => void;
  cohort: EventCohort;
}

export function EditGroupModal({ visible, onClose, cohort }: EditGroupModalProps) {
  const theme = useTheme();
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
      <View style={styles.backdrop}>
        <View style={[styles.card, { backgroundColor: theme.backgroundElement }]}>
          {/* Header */}
          <View style={styles.modalHeader}>
            <Text style={[styles.modalTitle, { color: theme.text }]}>Edit Group Info</Text>
            <TouchableOpacity onPress={onClose}>
              <Text style={[styles.closeX, { color: theme.textSecondary }]}>✕</Text>
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={styles.formContent}>
            {/* Event Name */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>EVENT / GROUP NAME</Text>
            <TextInput
              style={[styles.input, { backgroundColor: theme.backgroundSelected, color: theme.text }]}
              placeholder="Group name"
              placeholderTextColor={theme.textSecondary}
              value={name}
              onChangeText={setName}
            />

            {/* Description */}
            <Text style={[styles.label, { color: theme.textSecondary }]}>DESCRIPTION</Text>
            <TextInput
              style={[styles.input, { backgroundColor: theme.backgroundSelected, color: theme.text }]}
              placeholder="Description"
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
                  placeholder="e.g. Badminton, Movie Night"
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

            {/* Submit Button */}
            <TouchableOpacity style={styles.saveBtn} onPress={handleSave}>
              <Text style={styles.saveBtnText}>Save Changes</Text>
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
  saveBtn: {
    backgroundColor: '#6366F1',
    paddingVertical: 16,
    borderRadius: 14,
    alignItems: 'center',
    marginTop: 16,
  },
  saveBtnText: {
    color: '#FFFFFF',
    fontWeight: '800',
    fontSize: 16,
  },
});

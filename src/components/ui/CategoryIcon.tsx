import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

export type CategoryIconType =
  | 'trip'
  | 'house'
  | 'dining'
  | 'event'
  | 'transport'
  | 'utilities'
  | 'custom';

export const GENERIC_CUSTOM_ICONS: { name: keyof typeof Ionicons.glyphMap; label: string }[] = [
  { name: 'gift', label: 'Gift' },
  { name: 'cart', label: 'Shopping' },
  { name: 'fast-food', label: 'Snacks' },
  { name: 'beer', label: 'Party' },
  { name: 'cafe', label: 'Coffee' },
  { name: 'briefcase', label: 'Work' },
  { name: 'laptop', label: 'Tech' },
  { name: 'game-controller', label: 'Gaming' },
  { name: 'fitness', label: 'Gym' },
  { name: 'football', label: 'Sports' },
  { name: 'film', label: 'Movie' },
  { name: 'musical-notes', label: 'Music' },
  { name: 'camera', label: 'Photos' },
  { name: 'headset', label: 'Audio' },
  { name: 'medkit', label: 'Health' },
  { name: 'build', label: 'Tools' },
  { name: 'construct', label: 'Repair' },
  { name: 'paw', label: 'Pets' },
  { name: 'cash', label: 'Cash' },
  { name: 'school', label: 'Study' },
  { name: 'book', label: 'Books' },
  { name: 'bus', label: 'Transit' },
  { name: 'airplane', label: 'Flight' },
  { name: 'car-sport', label: 'Drive' },
  { name: 'heart', label: 'Love' },
  { name: 'shirt', label: 'Clothes' },
  { name: 'flame', label: 'Hot' },
  { name: 'sparkles', label: 'VIP' },
  { name: 'key', label: 'Rent' },
  { name: 'diamond', label: 'Luxe' },
];

interface CategoryIconProps {
  category: CategoryIconType | string;
  customIcon?: string;
  size?: number;
  color?: string;
}

export function CategoryIcon({
  category,
  customIcon,
  size = 36,
  color,
}: CategoryIconProps) {
  const cat = (category || 'custom').toLowerCase();

  let iconName: keyof typeof Ionicons.glyphMap = 'apps';
  let bgColor = '#64748B';

  switch (cat) {
    case 'trip':
      iconName = 'airplane';
      bgColor = '#6366F1';
      break;

    case 'house':
      iconName = 'home';
      bgColor = '#10B981';
      break;

    case 'dining':
      iconName = 'restaurant';
      bgColor = '#F59E0B';
      break;

    case 'event':
      iconName = 'calendar';
      bgColor = '#F43F5E';
      break;

    case 'transport':
      iconName = 'car';
      bgColor = '#0EA5E9';
      break;

    case 'utilities':
      iconName = 'flash';
      bgColor = '#8B5CF6';
      break;

    case 'custom':
    default:
      if (customIcon && (Ionicons.glyphMap as any)[customIcon]) {
        iconName = customIcon as keyof typeof Ionicons.glyphMap;
      } else {
        iconName = 'apps';
      }
      bgColor = '#EC4899';
      break;
  }

  const activeColor = color || bgColor;
  const iconSize = Math.round(size * 0.55);

  return (
    <View
      style={[
        styles.circle,
        {
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: activeColor,
        },
      ]}
    >
      <Ionicons name={iconName} size={iconSize} color="#FFFFFF" />
    </View>
  );
}

const styles = StyleSheet.create({
  circle: {
    alignItems: 'center',
    justifyContent: 'center',
  },
});

import React from 'react';
import { View } from 'react-native';
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
  variant?: 'solid' | 'light';
}

export function getCategoryMetadata(category?: string, customIcon?: string): {
  iconName: keyof typeof Ionicons.glyphMap;
  label: string;
  bgColor: string;
} {
  const cat = (category || 'custom').toLowerCase();
  switch (cat) {
    case 'trip':
      return { iconName: 'airplane', label: 'Trip', bgColor: '#334454' };
    case 'house':
      return { iconName: 'home', label: 'House', bgColor: '#2E4036' };
    case 'dining':
      return { iconName: 'restaurant', label: 'Dining', bgColor: '#42372E' };
    case 'event':
      return { iconName: 'calendar', label: 'Event', bgColor: '#44323B' };
    case 'transport':
      return { iconName: 'car', label: 'Transport', bgColor: '#303E48' };
    case 'utilities':
      return { iconName: 'flash', label: 'Utilities', bgColor: '#383344' };
    case 'custom':
    default: {
      let icon: keyof typeof Ionicons.glyphMap = 'apps';
      if (customIcon && (Ionicons.glyphMap as any)[customIcon]) {
        icon = customIcon as keyof typeof Ionicons.glyphMap;
      }
      const label =
        !category || cat === 'custom'
          ? (customIcon ? customIcon.charAt(0).toUpperCase() + customIcon.slice(1) : 'Custom')
          : category.charAt(0).toUpperCase() + category.slice(1);
      return { iconName: icon, label, bgColor: '#3A3E45' };
    }
  }
}

export function CategoryIcon({
  category,
  customIcon,
  size = 48,
  color,
  variant = 'solid',
}: CategoryIconProps) {
  const cat = (category || 'custom').toLowerCase();

  let iconName: keyof typeof Ionicons.glyphMap = 'apps';
  let bgColor = '#3A3E45';
  let iconColor = '#E2E8F0';

  switch (cat) {
    case 'trip':
      iconName = 'airplane';
      bgColor = '#334454';
      break;

    case 'house':
      iconName = 'home';
      bgColor = '#2E4036';
      break;

    case 'dining':
      iconName = 'restaurant';
      bgColor = '#42372E';
      break;

    case 'event':
      iconName = 'calendar';
      bgColor = '#44323B';
      break;

    case 'transport':
      iconName = 'car';
      bgColor = '#303E48';
      break;

    case 'utilities':
      iconName = 'flash';
      bgColor = '#383344';
      break;

    case 'custom':
    default:
      if (customIcon && (Ionicons.glyphMap as any)[customIcon]) {
        iconName = customIcon as keyof typeof Ionicons.glyphMap;
      } else {
        iconName = 'apps';
      }
      bgColor = '#3A3E45';
      break;
  }

  const activeColor = color || bgColor;
  const iconSize = Math.round(size * 0.52);

  if (variant === 'light') {
    return (
      <View
        style={{
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: 'rgba(148, 163, 184, 0.15)',
          borderWidth: 1,
          borderColor: 'rgba(148, 163, 184, 0.25)',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Ionicons name={iconName} size={iconSize} color="#94A3B8" />
      </View>
    );
  }

  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: activeColor,
        borderWidth: 1,
        borderColor: 'rgba(255, 255, 255, 0.15)',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      <Ionicons name={iconName} size={iconSize} color={iconColor} />
    </View>
  );
}

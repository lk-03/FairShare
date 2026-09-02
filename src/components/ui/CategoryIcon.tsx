import React from 'react';
import { View, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useThemeStore } from '@/store/useThemeStore';

export type CategoryIconType =
  | 'trip'
  | 'house'
  | 'dining'
  | 'event'
  | 'transport'
  | 'utilities'
  | 'settlement'
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

interface CategoryStyleConfig {
  iconName: keyof typeof Ionicons.glyphMap;
  label: string;
  darkBg: string;
  darkBorder: string;
  darkIcon: string;
  lightBg: string;
  lightBorder: string;
  lightIcon: string;
}

const CATEGORY_STYLES: Record<string, CategoryStyleConfig> = {
  trip: {
    iconName: 'airplane',
    label: 'Trip',
    darkBg: '#1E293B',
    darkBorder: '#334155',
    darkIcon: '#38BDF8',
    lightBg: '#E0F2FE',
    lightBorder: '#BAE6FD',
    lightIcon: '#0284C7',
  },
  house: {
    iconName: 'home',
    label: 'House',
    darkBg: '#1E2B26',
    darkBorder: '#2D3F36',
    darkIcon: '#34D399',
    lightBg: '#DCFCE7',
    lightBorder: '#BBF7D0',
    lightIcon: '#16A34A',
  },
  dining: {
    iconName: 'restaurant',
    label: 'Dining',
    darkBg: '#2E241E',
    darkBorder: '#42342A',
    darkIcon: '#FBBF24',
    lightBg: '#FEF3C7',
    lightBorder: '#FDE68A',
    lightIcon: '#D97706',
  },
  event: {
    iconName: 'calendar',
    label: 'Event',
    darkBg: '#2E1E28',
    darkBorder: '#422A39',
    darkIcon: '#F472B6',
    lightBg: '#FCE7F3',
    lightBorder: '#FBCFE8',
    lightIcon: '#DB2777',
  },
  transport: {
    iconName: 'car',
    label: 'Transport',
    darkBg: '#1E293B',
    darkBorder: '#334155',
    darkIcon: '#94A3B8',
    lightBg: '#F1F5F9',
    lightBorder: '#CBD5E1',
    lightIcon: '#475569',
  },
  utilities: {
    iconName: 'flash',
    label: 'Utilities',
    darkBg: '#251E38',
    darkBorder: '#362B4E',
    darkIcon: '#A78BFA',
    lightBg: '#EDE9FE',
    lightBorder: '#DDD6FE',
    lightIcon: '#7C3AED',
  },
  settlement: {
    iconName: 'cash',
    label: 'Settlement',
    darkBg: '#1E3A2B',
    darkBorder: '#284E3A',
    darkIcon: '#34D399',
    lightBg: '#D1FAE5',
    lightBorder: '#A7F3D0',
    lightIcon: '#059669',
  },
};

export function getCategoryMetadata(category?: string, customIcon?: string): {
  iconName: keyof typeof Ionicons.glyphMap;
  label: string;
  bgColor: string;
} {
  const cat = (category || 'custom').toLowerCase();
  const cfg = CATEGORY_STYLES[cat];
  if (cfg) {
    return { iconName: cfg.iconName, label: cfg.label, bgColor: cfg.darkBg };
  }

  let icon: keyof typeof Ionicons.glyphMap = 'apps';
  if (customIcon && (Ionicons.glyphMap as any)[customIcon]) {
    icon = customIcon as keyof typeof Ionicons.glyphMap;
  }
  const label =
    !category || cat === 'custom'
      ? (customIcon ? customIcon.charAt(0).toUpperCase() + customIcon.slice(1) : 'Custom')
      : category.charAt(0).toUpperCase() + category.slice(1);
  return { iconName: icon, label, bgColor: '#1E293B' };
}

export function CategoryIcon({
  category,
  customIcon,
  size = 48,
  color,
  variant = 'solid',
}: CategoryIconProps) {
  const systemScheme = useColorScheme();
  const { colorScheme } = useThemeStore();
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const cat = (category || 'custom').toLowerCase();
  const cfg = CATEGORY_STYLES[cat];

  let iconName: keyof typeof Ionicons.glyphMap = 'apps';
  let bgColor = isDark ? '#1E293B' : '#F1F5F9';
  let borderColor = isDark ? '#334155' : '#E2E8F0';
  let iconColor = isDark ? '#38BDF8' : '#0284C7';

  if (cfg) {
    iconName = cfg.iconName;
    bgColor = isDark ? cfg.darkBg : cfg.lightBg;
    borderColor = isDark ? cfg.darkBorder : cfg.lightBorder;
    iconColor = isDark ? cfg.darkIcon : cfg.lightIcon;
  } else if (customIcon && (Ionicons.glyphMap as any)[customIcon]) {
    iconName = customIcon as keyof typeof Ionicons.glyphMap;
  }

  const activeBg = color || bgColor;
  const iconSize = Math.round(size * 0.50);

  if (variant === 'light') {
    return (
      <View
        style={{
          width: size,
          height: size,
          borderRadius: size / 2,
          backgroundColor: isDark ? 'rgba(148, 163, 184, 0.15)' : 'rgba(100, 116, 139, 0.08)',
          borderWidth: 1,
          borderColor: isDark ? 'rgba(148, 163, 184, 0.25)' : 'rgba(100, 116, 139, 0.15)',
          alignItems: 'center',
          justifyContent: 'center',
          elevation: 0,
          shadowOpacity: 0,
        }}
      >
        <Ionicons name={iconName} size={iconSize} color={isDark ? '#94A3B8' : '#64748B'} />
      </View>
    );
  }

  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: activeBg,
        borderWidth: 1,
        borderColor: borderColor,
        alignItems: 'center',
        justifyContent: 'center',
        elevation: 0,
        shadowOpacity: 0,
      }}
    >
      <Ionicons name={iconName} size={iconSize} color={iconColor} />
    </View>
  );
}

import React from 'react';
import { View } from 'react-native';
import { Image } from 'expo-image';
import { CategoryIcon } from './CategoryIcon';
import { EventCategory } from '@/types';

export interface GroupAvatarProps {
  avatarUrl?: string | null;
  category: EventCategory | string;
  customIcon?: string;
  size?: number;
  variant?: 'solid' | 'light';
  className?: string;
}

export function GroupAvatar({
  avatarUrl,
  category,
  customIcon,
  size = 48,
  variant = 'solid',
  className = '',
}: GroupAvatarProps) {
  if (avatarUrl) {
    return (
      <View
        className={className}
        style={{
          width: size,
          height: size,
          borderRadius: size / 2,
          overflow: 'hidden',
          borderWidth: 1.5,
          borderColor: 'rgba(255, 255, 255, 0.2)',
          backgroundColor: '#1E293B',
        }}
      >
        <Image
          source={{ uri: avatarUrl }}
          style={{ width: size, height: size }}
          contentFit="cover"
          transition={200}
        />
      </View>
    );
  }

  return (
    <CategoryIcon
      category={category}
      customIcon={customIcon}
      size={size}
      variant={variant}
    />
  );
}

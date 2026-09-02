import React from 'react';
import { View, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

export interface EmptyStateProps {
  icon?: keyof typeof Ionicons.glyphMap;
  title: string;
  description: string;
  primaryActionLabel?: string;
  onPrimaryAction?: () => void;
  secondaryActionLabel?: string;
  onSecondaryAction?: () => void;
  variant?: 'card' | 'inline';
  className?: string;
}

export function EmptyState({
  icon = 'wallet-outline',
  title,
  description,
  primaryActionLabel,
  onPrimaryAction,
  secondaryActionLabel,
  onSecondaryAction,
  variant = 'card',
  className = '',
}: EmptyStateProps) {
  const isCard = variant === 'card';

  return (
    <View
      className={`${
        isCard
          ? 'card-main p-7 items-center justify-center border border-surface bg-surface shadow-sm'
          : 'items-center justify-center p-4'
      } ${className}`}
    >
      {/* Icon Pill */}
      <View className="w-16 h-16 rounded-3xl bg-accent-pill border border-surface items-center justify-center mb-4 shadow-sm">
        <Ionicons name={icon} size={28} color="#94A3B8" />
      </View>

      {/* Title */}
      <Text className="text-base font-bold text-main text-center mb-1">
        {title}
      </Text>

      {/* Description */}
      <Text className="text-xs text-secondary text-center leading-relaxed max-w-[280px] mb-5">
        {description}
      </Text>

      {/* Action Buttons */}
      {(primaryActionLabel || secondaryActionLabel) && (
        <View className="flex-row items-center gap-3 w-full justify-center">
          {secondaryActionLabel && onSecondaryAction && (
            <TouchableOpacity
              activeOpacity={0.8}
              className="py-2.5 px-4 rounded-xl border border-surface bg-accent-pill items-center justify-center"
              onPress={onSecondaryAction}
            >
              <Text className="text-xs font-semibold text-secondary">
                {secondaryActionLabel}
              </Text>
            </TouchableOpacity>
          )}

          {primaryActionLabel && onPrimaryAction && (
            <TouchableOpacity
              activeOpacity={0.8}
              className="py-2.5 px-5 rounded-xl bg-main items-center justify-center shadow-sm"
              onPress={onPrimaryAction}
            >
              <Text className="text-xs font-bold text-screen">
                {primaryActionLabel}
              </Text>
            </TouchableOpacity>
          )}
        </View>
      )}
    </View>
  );
}

import React from 'react';
import { StyleSheet, View, Text, TouchableOpacity } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { useTheme } from '@/hooks/use-theme';

import { Ionicons } from '@expo/vector-icons';

interface TitleBarProps {
  title?: string;
  onNotificationPress?: () => void;
  onProfilePress?: () => void;
  onLayoutToggle?: () => void;
  isGroupsOnlyView?: boolean;
}

export function TitleBar({
  title = 'fairsharew',
  onNotificationPress,
  onProfilePress,
  onLayoutToggle,
  isGroupsOnlyView = false,
}: TitleBarProps) {
  const insets = useSafeAreaInsets();
  const theme = useTheme();

  return (
    <View
      style={[
        styles.container,
        {
          paddingTop: Math.max(insets.top, 12),
          backgroundColor: theme.backgroundElement,
        },
      ]}
    >
      <View style={styles.content}>
        <View style={styles.titleSection}>
          <Text style={[styles.titleText, { color: theme.text }]}>{title}</Text>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>PRO</Text>
          </View>
        </View>

        <View style={styles.actionSection}>
          {/* Layout Toggle Button */}
          {onLayoutToggle && (
            <TouchableOpacity
              style={[
                styles.iconButton,
                {
                  backgroundColor: isGroupsOnlyView
                    ? '#6366F1'
                    : theme.backgroundSelected,
                },
              ]}
              onPress={onLayoutToggle}
              activeOpacity={0.7}
            >
              <Ionicons
                name={isGroupsOnlyView ? 'grid-outline' : 'list-outline'}
                size={16}
                color={theme.text}
              />
            </TouchableOpacity>
          )}

          {/* Notification Bell */}
          <TouchableOpacity
            style={[styles.iconButton, { backgroundColor: theme.backgroundSelected }]}
            onPress={onNotificationPress}
            activeOpacity={0.7}
          >
            <Ionicons name="notifications-outline" size={16} color={theme.text} />
          </TouchableOpacity>

          {/* User Profile Avatar */}
          <TouchableOpacity
            style={[styles.avatarButton, { backgroundColor: '#6366F1' }]}
            onPress={onProfilePress}
            activeOpacity={0.7}
          >
            <Text style={styles.avatarText}>FS</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 16,
    paddingBottom: 12,
    borderBottomWidth: 1,
    borderBottomColor: 'rgba(150, 150, 150, 0.15)',
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: 44,
  },
  titleSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  titleText: {
    fontSize: 22,
    fontWeight: '700',
    letterSpacing: -0.5,
  },
  badge: {
    backgroundColor: '#6366F1',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 10,
    fontWeight: '800',
  },
  actionSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  iconButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconSymbol: {
    fontSize: 16,
  },
  avatarButton: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#FFFFFF',
    fontWeight: '700',
    fontSize: 13,
  },
});

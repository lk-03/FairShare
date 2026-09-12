import React from 'react';
import { View, TouchableOpacity, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';

export function BottomNav({ state, descriptors, navigation }: any) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  if (!state || !state.routes) {
    return null;
  }

  return (
    <View
      className="bottom-nav-bar"
      style={{ backgroundColor: colors.surface, borderTopColor: colors.border }}
    >
      {state.routes.map((route: any, index: number) => {
        const { options } = descriptors[route.key] || {};
        const isFocused = state.index === index;
        const label = options?.title || route.name;

        const onPress = () => {
          const event = navigation.emit({
            type: 'tabPress',
            target: route.key,
            canPreventDefault: true,
          });

          if (!isFocused && !event.defaultPrevented) {
            navigation.navigate(route.name);
          }
        };

        let iconName: keyof typeof Ionicons.glyphMap = 'home-outline';
        let activeIconName: keyof typeof Ionicons.glyphMap = 'home';
        if (route.name === 'groups') {
          iconName = 'people-outline';
          activeIconName = 'people';
        } else if (route.name === 'activity') {
          iconName = 'time-outline';
          activeIconName = 'time';
        } else if (route.name === 'profile') {
          iconName = 'person-outline';
          activeIconName = 'person';
        }

        return (
          <TouchableOpacity
            key={route.key}
            onPress={onPress}
            className="tab-item"
            activeOpacity={0.7}
          >
            <Ionicons
              name={isFocused ? activeIconName : iconName}
              size={22}
              color={isFocused ? colors.cyan : colors.textSecondary}
            />
            <Text
              className="text-[11px] mt-1 font-semibold"
              style={{ color: isFocused ? colors.textMain : colors.textSecondary }}
            >
              {label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}

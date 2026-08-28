import React from 'react';
import { View, TouchableOpacity, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';

export function BottomNav({ state, descriptors, navigation }: any) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  return (
    <View className="bottom-nav-bar" style={{ backgroundColor: colors.surface, borderTopColor: colors.border }}>
      {state.routes.map((route: any, index: number) => {
        const { options } = descriptors[route.key];
        const isFocused = state.index === index;
        const label = options.title || route.name;

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

        let iconName: any = 'home-outline';
        if (route.name === 'groups') iconName = 'people-outline';
        if (route.name === 'activity') iconName = 'time-outline';
        if (route.name === 'profile') iconName = 'person-outline';

        if (isFocused) {
          iconName = iconName.replace('-outline', '');
        }

        return (
          <TouchableOpacity
            key={route.key}
            onPress={onPress}
            className="tab-item"
            activeOpacity={0.7}
          >
            <Ionicons
              name={iconName}
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

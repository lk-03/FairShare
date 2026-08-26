import React from 'react';
import { View, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Text } from '@/components/ui/Text';

export function BottomNav({ state, descriptors, navigation }: any) {
  return (
    <View className="bottom-nav-bar">
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
              color={isFocused ? '#E2E8F0' : '#64748B'}
            />
            <Text className={isFocused ? 'tab-label-active' : 'tab-label-inactive'}>
              {label}
            </Text>
          </TouchableOpacity>
        );
      })}
    </View>
  );
}


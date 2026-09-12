import React from 'react';
import { View, Image, useColorScheme, ViewStyle, StyleProp } from 'react-native';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';

interface AppLogoProps {
  size?: number;
  color?: string;
  withGlow?: boolean;
  withShadow?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function AppLogo({
  size = 32,
  color,
  withGlow = false,
  withShadow = true,
  style,
}: AppLogoProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const accentColor = color || colors.cyan;

  return (
    <View
      style={[
        {
          width: size,
          height: size,
          alignItems: 'center',
          justifyContent: 'center',
        },
        withShadow && {
          shadowColor: accentColor,
          shadowOffset: { width: 0, height: 3 },
          shadowOpacity: 0.35,
          shadowRadius: 6,
          elevation: 5,
        },
        style,
      ]}
    >
      {withGlow && (
        <View
          style={{
            position: 'absolute',
            width: size * 1.15,
            height: size * 1.15,
            borderRadius: size,
            backgroundColor: `${accentColor}18`,
          }}
        />
      )}
      <Image
        source={require('@/assets/images/logo-symbol.png')}
        style={{
          width: size,
          height: size,
          tintColor: accentColor,
        }}
        resizeMode="contain"
      />
    </View>
  );
}

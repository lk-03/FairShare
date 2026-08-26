import React, { useState } from 'react';
import { View, ViewProps, StyleSheet, LayoutChangeEvent } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Svg, { Defs, LinearGradient as SvgLinearGradient, Stop, Rect } from 'react-native-svg';

export interface ThemeGradientHeaderProps extends ViewProps {
  colors: [string, string, string];
  borderRadius?: number;
  className?: string;
  children?: React.ReactNode;
}

export function ThemeGradientHeader({
  colors,
  borderRadius = 40,
  className,
  style,
  children,
  ...props
}: ThemeGradientHeaderProps) {
  const insets = useSafeAreaInsets();
  const [dimensions, setDimensions] = useState<{ width: number; height: number }>({
    width: 0,
    height: 0,
  });

  const handleLayout = (e: LayoutChangeEvent) => {
    const { width, height } = e.nativeEvent.layout;
    setDimensions({ width, height });
  };

  const topPadding = Math.max(insets.top, 16) + 12;

  return (
    <View
      onLayout={handleLayout}
      className={className}
      style={[
        {
          paddingTop: topPadding,
          position: 'relative',
          overflow: 'hidden',
          backgroundColor: colors[0],
        },
        style,
      ]}
      {...props}
    >
      {/* Underlying 3-stop SVG Linear Gradient */}
      {dimensions.width > 0 && dimensions.height > 0 && (
        <Svg
          width={dimensions.width}
          height={dimensions.height}
          style={StyleSheet.absoluteFill}
        >
          <Defs>
            <SvgLinearGradient id="heroGradient" x1="0" y1="0" x2="0" y2="1">
              <Stop offset="0%" stopColor={colors[0]} stopOpacity="1" />
              <Stop offset="45%" stopColor={colors[1]} stopOpacity="1" />
              <Stop offset="100%" stopColor={colors[2]} stopOpacity="1" />
            </SvgLinearGradient>
          </Defs>
          <Rect
            x="0"
            y="0"
            width={dimensions.width}
            height={dimensions.height}
            fill="url(#heroGradient)"
          />
        </Svg>
      )}

      {/* Content Container */}
      <View style={{ zIndex: 1 }}>{children}</View>
    </View>
  );
}

import React from 'react';
import { Text as RNText, TextProps } from 'react-native';

export function Text({ className, style, ...props }: TextProps & { className?: string }) {
  return <RNText className={className} style={style} {...props} />;
}

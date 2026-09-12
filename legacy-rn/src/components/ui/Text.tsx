import React from 'react';
import { Text as RNText, TextProps } from 'react-native';

export function Text({ className = '', style, ...props }: TextProps & { className?: string }) {
  const hasColor =
    /\btext-(main|secondary|positive|negative|screen|sky|emerald|rose|amber|slate|white|black|indigo|pink|teal|chart)\b/.test(
      className
    ) || /\bbalance-(positive|negative)\b/.test(className);

  const mergedClassName = hasColor ? className : `text-main ${className}`.trim();

  return <RNText className={mergedClassName} style={style} {...props} />;
}

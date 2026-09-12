import React from 'react';
import { TouchableOpacity, TouchableOpacityProps } from 'react-native';

export interface ButtonProps extends TouchableOpacityProps {
  variant?: 'default' | 'ghost' | 'outline';
  size?: 'default' | 'icon';
  className?: string;
}

export function Button({ className, variant = 'default', size = 'default', ...props }: ButtonProps) {
  let baseClass = 'items-center justify-center flex-row gap-2 ';
  
  if (variant === 'default') baseClass += 'bg-slate-900 ';
  else if (variant === 'outline') baseClass += 'bg-white border border-slate-200 ';
  else if (variant === 'ghost') baseClass += 'bg-transparent ';

  if (size === 'default') baseClass += 'py-4 px-6 rounded-xl ';
  else if (size === 'icon') baseClass += 'h-10 w-10 rounded-full ';

  return (
    <TouchableOpacity
      className={`${baseClass} ${className || ''}`}
      activeOpacity={0.8}
      {...props}
    />
  );
}

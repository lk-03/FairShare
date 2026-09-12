import { Colors } from '@/constants/theme';
import { useThemeStore } from '@/store/useThemeStore';
import { useColorScheme } from 'react-native';

export function useTheme() {
  const systemScheme = useColorScheme();
  const { colorScheme } = useThemeStore();

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  return isDark ? Colors.dark : Colors.light;
}

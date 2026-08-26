import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';
import { zustandMMKVStorage } from '@/services/storage/mmkv';

export type ThemeBase = 'nordic' | 'sage' | 'taupe' | 'cobalt';
export type ColorSchemeOption = 'light' | 'dark' | 'system';

interface ThemeState {
  themeBase: ThemeBase;
  colorScheme: ColorSchemeOption;
  setThemeBase: (theme: ThemeBase) => void;
  setColorScheme: (scheme: ColorSchemeOption) => void;
}

export const THEME_GRADIENTS: Record<
  ThemeBase,
  { dark: [string, string, string]; light: [string, string, string] }
> = {
  nordic: {
    dark: ['#2B3E50', '#182533', '#0D131A'],
    light: ['#DCE7F0', '#EDF2F7', '#F8FAFC'],
  },
  sage: {
    dark: ['#33453E', '#1E2B26', '#0E1412'],
    light: ['#DFE8E2', '#EFF4F1', '#F7FAF8'],
  },
  taupe: {
    dark: ['#3D3534', '#241E1E', '#110E0E'],
    light: ['#EBE5DF', '#F6F3F0', '#FAF8F6'],
  },
  cobalt: {
    dark: ['#2563EB', '#1D4ED8', '#080C14'],
    light: ['#DBEAFE', '#EFF6FF', '#F8FAFF'],
  },
};

export const THEME_METADATA: Record<
  ThemeBase,
  { name: string; subtitle: string; icon: string; previewColor: string }
> = {
  nordic: {
    name: 'Nordic Steel',
    subtitle: 'Understated Scandinavian Blue',
    icon: 'snow-outline',
    previewColor: '#2B3E50',
  },
  sage: {
    name: 'Muted Sage',
    subtitle: 'Organic Eucalyptus & Pine',
    icon: 'leaf-outline',
    previewColor: '#33453E',
  },
  taupe: {
    name: 'Warm Taupe',
    subtitle: 'Cozy Sand & Mocha Clay',
    icon: 'cafe-outline',
    previewColor: '#3D3534',
  },
  cobalt: {
    name: 'Electric Cobalt',
    subtitle: 'High-Tech Neo-Fintech Blue',
    icon: 'flash-outline',
    previewColor: '#2563EB',
  },
};

export const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      themeBase: 'nordic',
      colorScheme: 'system',
      setThemeBase: (themeBase) => set({ themeBase }),
      setColorScheme: (colorScheme) => set({ colorScheme }),
    }),
    {
      name: 'fairshare-theme-store',
      storage: createJSONStorage(() => zustandMMKVStorage),
    }
  )
);

export function getActiveThemeClass(
  themeBase: ThemeBase,
  colorScheme: ColorSchemeOption,
  systemScheme?: string | null
): string {
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const mode = isDark ? 'dark' : 'light';
  return `theme-${themeBase}-${mode}`;
}

export function getThemeGradientColors(
  themeBase: ThemeBase,
  colorScheme: ColorSchemeOption,
  systemScheme?: string | null
): [string, string, string] {
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  return isDark ? THEME_GRADIENTS[themeBase].dark : THEME_GRADIENTS[themeBase].light;
}

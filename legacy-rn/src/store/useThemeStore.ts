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

export interface ThemePaletteColors {
  screen: string;
  surface: string;
  border: string;
  textMain: string;
  textSecondary: string;
  accentPill: string;
  cyan: string; // The primary theme accent color
  red: string;
  amber: string;
  emerald: string;
}

export const THEME_PALETTES: Record<
  ThemeBase,
  { dark: ThemePaletteColors; light: ThemePaletteColors }
> = {
  nordic: {
    dark: {
      screen: '#0D131A',
      surface: '#121A23',
      border: '#243447',
      textMain: '#FFFFFF',
      textSecondary: '#7E95A8',
      accentPill: 'rgba(255, 255, 255, 0.10)',
      cyan: '#38BDF8',
      red: '#F87171',
      amber: '#FBBF24',
      emerald: '#34D399',
    },
    light: {
      screen: '#F8FAFC',
      surface: '#FFFFFF',
      border: '#E2E8F0',
      textMain: '#0F172A',
      textSecondary: '#64748B',
      accentPill: 'rgba(0, 0, 0, 0.05)',
      cyan: '#0284C7',
      red: '#E11D48',
      amber: '#D97706',
      emerald: '#059669',
    },
  },
  sage: {
    dark: {
      screen: '#0E1412',
      surface: '#141C19',
      border: '#24332D',
      textMain: '#FFFFFF',
      textSecondary: '#8BA398',
      accentPill: 'rgba(255, 255, 255, 0.10)',
      cyan: '#34D399',
      red: '#F87171',
      amber: '#FBBF24',
      emerald: '#34D399',
    },
    light: {
      screen: '#F7FAF8',
      surface: '#FFFFFF',
      border: '#DCE6E0',
      textMain: '#14201A',
      textSecondary: '#586B62',
      accentPill: 'rgba(0, 0, 0, 0.05)',
      cyan: '#059669',
      red: '#E11D48',
      amber: '#D97706',
      emerald: '#059669',
    },
  },
  taupe: {
    dark: {
      screen: '#110E0E',
      surface: '#181414',
      border: '#2E2626',
      textMain: '#FFFFFF',
      textSecondary: '#C4B5A5',
      accentPill: 'rgba(255, 255, 255, 0.10)',
      cyan: '#F59E0B',
      red: '#F87171',
      amber: '#FBBF24',
      emerald: '#34D399',
    },
    light: {
      screen: '#FAF8F6',
      surface: '#FFFFFF',
      border: '#EBE4DC',
      textMain: '#1C1717',
      textSecondary: '#7A6A5F',
      accentPill: 'rgba(0, 0, 0, 0.05)',
      cyan: '#D97706',
      red: '#E11D48',
      amber: '#B45309',
      emerald: '#059669',
    },
  },
  cobalt: {
    dark: {
      screen: '#080C14',
      surface: '#0F172A',
      border: '#1E293B',
      textMain: '#FFFFFF',
      textSecondary: '#94A3B8',
      accentPill: 'rgba(255, 255, 255, 0.10)',
      cyan: '#38BDF8',
      red: '#F87171',
      amber: '#FBBF24',
      emerald: '#34D399',
    },
    light: {
      screen: '#F8FAFF',
      surface: '#FFFFFF',
      border: '#DBEAFE',
      textMain: '#0F172A',
      textSecondary: '#475569',
      accentPill: 'rgba(0, 0, 0, 0.05)',
      cyan: '#2563EB',
      red: '#E11D48',
      amber: '#D97706',
      emerald: '#059669',
    },
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

export function getThemePalette(
  themeBase: ThemeBase,
  colorScheme: ColorSchemeOption,
  systemScheme?: string | null
): ThemePaletteColors {
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  return isDark ? THEME_PALETTES[themeBase].dark : THEME_PALETTES[themeBase].light;
}

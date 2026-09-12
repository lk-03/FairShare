import { create } from 'zustand';
import { Ionicons } from '@expo/vector-icons';

export interface AlertButton {
  text: string;
  onPress?: () => void;
  style?: 'default' | 'cancel' | 'destructive';
  icon?: keyof typeof Ionicons.glyphMap;
}

export interface AlertConfig {
  title: string;
  message?: string;
  icon?: keyof typeof Ionicons.glyphMap;
  iconColor?: string;
  buttons?: AlertButton[];
  onDismiss?: () => void;
}

interface AlertState {
  currentAlert: AlertConfig | null;
  showAlert: (config: AlertConfig) => void;
  hideAlert: () => void;
}

export const useAlertStore = create<AlertState>((set) => ({
  currentAlert: null,
  showAlert: (config) => set({ currentAlert: config }),
  hideAlert: () => set({ currentAlert: null }),
}));

/**
 * Universal helper function to show custom-styled FairShare dialogs and action sheets.
 * Provides drop-in support for standard Alert.alert signatures.
 */
export function showAlert(
  title: string,
  message?: string,
  buttons?: AlertButton[],
  options?: Partial<Omit<AlertConfig, 'title' | 'message' | 'buttons'>>
) {
  useAlertStore.getState().showAlert({
    title,
    message,
    buttons: buttons && buttons.length > 0 ? buttons : [{ text: 'OK', style: 'default' }],
    ...options,
  });
}

export function hideAlert() {
  useAlertStore.getState().hideAlert();
}

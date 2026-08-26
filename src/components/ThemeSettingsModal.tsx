import React from 'react';
import { View, Modal, TouchableOpacity, ScrollView } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { ThemeGradientHeader } from '@/components/ui/ThemeGradientHeader';
import {
  useThemeStore,
  THEME_METADATA,
  THEME_GRADIENTS,
  ThemeBase,
  ColorSchemeOption,
} from '@/store/useThemeStore';
import { Text } from '@/components/ui/Text';

interface ThemeSettingsModalProps {
  visible: boolean;
  onClose: () => void;
}

export function ThemeSettingsModal({ visible, onClose }: ThemeSettingsModalProps) {
  const { themeBase, colorScheme, setThemeBase, setColorScheme } = useThemeStore();

  const themes: ThemeBase[] = ['nordic', 'sage', 'taupe', 'cobalt'];
  const modes: { label: string; value: ColorSchemeOption; icon: string }[] = [
    { label: 'System', value: 'system', icon: 'phone-portrait-outline' },
    { label: 'Light', value: 'light', icon: 'sunny-outline' },
    { label: 'Dark', value: 'dark', icon: 'moon-outline' },
  ];

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <TouchableOpacity
        className="flex-1 bg-black/60 justify-end"
        activeOpacity={1}
        onPress={onClose}
      >
        <TouchableOpacity
          activeOpacity={1}
          className="bg-surface rounded-t-3xl p-6 border-t border-surface max-h-[85%]"
        >
          {/* Header */}
          <View className="flex-row justify-between items-center mb-6">
            <View>
              <Text className="text-xl font-extrabold text-main">Theme & Appearance</Text>
              <Text className="text-xs text-secondary mt-0.5">Customize your visual aesthetic</Text>
            </View>
            <TouchableOpacity
              onPress={onClose}
              className="w-9 h-9 rounded-full bg-accent-pill items-center justify-center border border-surface"
            >
              <Ionicons name="close" size={20} color="#94A3B8" />
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-6 pb-6">
            {/* Mode Selector */}
            <View>
              <Text className="section-label mb-3">APPEARANCE MODE</Text>
              <View className="flex-row bg-accent-pill p-1 rounded-2xl border border-surface gap-1">
                {modes.map((m) => {
                  const isSelected = colorScheme === m.value;
                  return (
                    <TouchableOpacity
                      key={m.value}
                      activeOpacity={0.8}
                      className={`flex-1 py-2.5 rounded-xl flex-row items-center justify-center gap-1.5 ${
                        isSelected ? 'bg-surface shadow-sm border border-surface' : ''
                      }`}
                      onPress={() => setColorScheme(m.value)}
                    >
                      <Ionicons
                        name={m.icon as any}
                        size={16}
                        color={isSelected ? '#38BDF8' : '#94A3B8'}
                      />
                      <Text
                        className={`text-xs font-bold ${
                          isSelected ? 'text-main' : 'text-secondary'
                        }`}
                      >
                        {m.label}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </View>
            </View>

            {/* Accent Palette Selector */}
            <View>
              <Text className="section-label mb-3">COLOR PALETTE</Text>
              <View className="gap-3">
                {themes.map((t) => {
                  const isSelected = themeBase === t;
                  const meta = THEME_METADATA[t];
                  const grads = THEME_GRADIENTS[t].dark;

                  return (
                    <TouchableOpacity
                      key={t}
                      activeOpacity={0.8}
                      className={`p-4 rounded-2xl border flex-row items-center justify-between ${
                        isSelected
                          ? 'border-sky-500/80 bg-accent-pill'
                          : 'border-surface bg-surface'
                      }`}
                      onPress={() => setThemeBase(t)}
                    >
                      <View className="flex-row items-center gap-3.5 flex-1 pr-3">
                        <View
                          style={{ backgroundColor: meta.previewColor }}
                          className="w-12 h-12 rounded-xl items-center justify-center border border-white/20 shadow-sm"
                        >
                          <Ionicons name={meta.icon as any} size={22} color="#FFFFFF" />
                        </View>

                        <View className="flex-1">
                          <View className="flex-row items-center gap-2">
                            <Text className="text-base font-bold text-main">{meta.name}</Text>
                            {isSelected && (
                              <View className="bg-sky-500/20 px-2 py-0.5 rounded-full border border-sky-500/30">
                                <Text className="text-[10px] font-bold text-sky-400">ACTIVE</Text>
                              </View>
                            )}
                          </View>
                          <Text className="text-xs text-secondary mt-0.5">{meta.subtitle}</Text>
                        </View>
                      </View>

                      <View
                        className={`w-6 h-6 rounded-full border items-center justify-center ${
                          isSelected
                            ? 'bg-sky-500 border-sky-500'
                            : 'border-secondary/40'
                        }`}
                      >
                        {isSelected && <Ionicons name="checkmark" size={14} color="#FFFFFF" />}
                      </View>
                    </TouchableOpacity>
                  );
                })}
              </View>
            </View>
          </ScrollView>
        </TouchableOpacity>
      </TouchableOpacity>
    </Modal>
  );
}

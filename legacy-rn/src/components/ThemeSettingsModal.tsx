import React from 'react';
import { View, Modal, TouchableOpacity, ScrollView, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import {
  useThemeStore,
  getActiveThemeClass,
  getThemePalette,
  THEME_METADATA,
  ThemeBase,
  ColorSchemeOption,
} from '@/store/useThemeStore';
import { Text } from '@/components/ui/Text';

interface ThemeSettingsModalProps {
  visible: boolean;
  onClose: () => void;
}

export function ThemeSettingsModal({ visible, onClose }: ThemeSettingsModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme, setThemeBase, setColorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

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
      <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
        <TouchableOpacity
          className="flex-1"
          activeOpacity={1}
          onPress={onClose}
        />
        <View
          className="rounded-t-3xl p-6 max-h-[85%]"
          style={{ backgroundColor: colors.surface, borderTopWidth: 1, borderTopColor: colors.border }}
        >
          {/* Header */}
          <View className="flex-row justify-between items-center mb-6">
            <View>
              <Text className="text-xl font-extrabold" style={{ color: colors.textMain }}>
                Theme & Appearance
              </Text>
              <Text className="text-xs mt-0.5" style={{ color: colors.textSecondary }}>
                Customize your visual aesthetic
              </Text>
            </View>
            <TouchableOpacity
              onPress={onClose}
              className="w-9 h-9 rounded-full items-center justify-center"
              style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
            >
              <Ionicons name="close" size={20} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>

          <ScrollView showsVerticalScrollIndicator={false} contentContainerClassName="gap-6 pb-6">
            {/* Mode Selector */}
            <View>
              <Text className="section-label mb-3">APPEARANCE MODE</Text>
              <View
                className="flex-row p-1 rounded-2xl gap-1"
                style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
              >
                {modes.map((m) => {
                  const isSelected = colorScheme === m.value;
                  return (
                    <TouchableOpacity
                      key={m.value}
                      activeOpacity={0.8}
                      className="flex-1 py-2.5 rounded-xl flex-row items-center justify-center gap-1.5"
                      style={{
                        backgroundColor: isSelected ? colors.surface : 'transparent',
                        borderWidth: isSelected ? 1 : 0,
                        borderColor: isSelected ? colors.border : 'transparent',
                      }}
                      onPress={() => setColorScheme(m.value)}
                    >
                      <Ionicons
                        name={m.icon as any}
                        size={16}
                        color={isSelected ? colors.cyan : colors.textSecondary}
                      />
                      <Text
                        className="text-xs font-bold"
                        style={{ color: isSelected ? colors.textMain : colors.textSecondary }}
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

                  return (
                    <TouchableOpacity
                      key={t}
                      activeOpacity={0.8}
                      className="p-4 rounded-2xl flex-row items-center justify-between"
                      style={{
                        backgroundColor: isSelected ? colors.accentPill : colors.surface,
                        borderWidth: 1.5,
                        borderColor: isSelected ? colors.cyan : colors.border,
                      }}
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
                            <Text className="text-base font-bold" style={{ color: colors.textMain }}>
                              {meta.name}
                            </Text>
                            {isSelected && (
                              <View
                                className="px-2 py-0.5 rounded-full"
                                style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.cyan }}
                              >
                                <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
                                  ACTIVE
                                </Text>
                              </View>
                            )}
                          </View>
                          <Text className="text-xs mt-0.5" style={{ color: colors.textSecondary }}>
                            {meta.subtitle}
                          </Text>
                        </View>
                      </View>

                      <View
                        className="w-6 h-6 rounded-full items-center justify-center"
                        style={{
                          backgroundColor: isSelected ? colors.cyan : 'transparent',
                          borderWidth: 1,
                          borderColor: isSelected ? colors.cyan : colors.textSecondary,
                        }}
                      >
                        {isSelected && <Ionicons name="checkmark" size={14} color="#0F172A" />}
                      </View>
                    </TouchableOpacity>
                  );
                })}
              </View>
            </View>
          </ScrollView>
        </View>
      </View>
    </Modal>
  );
}

import React from 'react';
import { View, Modal, TouchableOpacity, useColorScheme } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useAlertStore, AlertButton } from '@/store/useAlertStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { Text } from '@/components/ui/Text';

export function CustomAlertModal() {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { currentAlert, hideAlert } = useAlertStore();

  if (!currentAlert) return null;

  const { title, message, icon, iconColor, buttons = [{ text: 'OK', style: 'default' }], onDismiss } = currentAlert;

  const handleClose = () => {
    hideAlert();
    if (onDismiss) onDismiss();
  };

  const handleButtonPress = (btn: AlertButton) => {
    hideAlert();
    if (btn.onPress) {
      btn.onPress();
    }
  };

  // Derive an icon if not explicitly provided
  const derivedIcon = icon || (
    buttons.some((b) => b.style === 'destructive')
      ? 'trash-outline'
      : title.toLowerCase().includes('shortcut')
      ? 'bookmark'
      : title.toLowerCase().includes('success') || title.toLowerCase().includes('saved')
      ? 'checkmark-circle'
      : title.toLowerCase().includes('mismatch') || title.toLowerCase().includes('invalid') || title.toLowerCase().includes('required') || title.toLowerCase().includes('missing')
      ? 'alert-circle-outline'
      : 'information-circle-outline'
  );

  const derivedIconColor = iconColor || (
    buttons.some((b) => b.style === 'destructive')
      ? colors.red
      : title.toLowerCase().includes('saved') || title.toLowerCase().includes('success') || title.toLowerCase().includes('joined')
      ? colors.cyan
      : colors.cyan
  );

  const isActionSheet = buttons.length >= 3;
  const isDualButtons = buttons.length === 2;

  return (
    <Modal visible={!!currentAlert} transparent animationType="fade" onRequestClose={handleClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/60 items-center justify-center p-5`}>
        <TouchableOpacity className="absolute inset-0" activeOpacity={1} onPress={handleClose} />

        <View
          className="w-full max-w-[360px] rounded-[28px] p-6 gap-4 shadow-2xl items-center"
          style={{
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
          }}
        >
          {/* Top Themed Badge Icon */}
          <View
            className="w-13 h-13 rounded-2xl items-center justify-center p-3"
            style={{
              backgroundColor: colors.accentPill,
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <Ionicons name={derivedIcon as any} size={28} color={derivedIconColor} />
          </View>

          {/* Title & Message */}
          <View className="items-center gap-1.5 w-full">
            <Text className="text-lg font-bold text-center" style={{ color: colors.textMain }}>
              {title}
            </Text>
            {message ? (
              <Text className="text-xs text-center leading-relaxed font-medium" style={{ color: colors.textSecondary }}>
                {message}
              </Text>
            ) : null}
          </View>

          {/* Action Buttons Layout */}
          {isActionSheet ? (
            /* Vertical Action Sheet List */
            <View className="w-full gap-2 pt-2">
              {buttons.map((btn, index) => {
                const isDestructive = btn.style === 'destructive';
                const isCancel = btn.style === 'cancel';
                const isPrimary = btn.style === 'default' || (!isDestructive && !isCancel);

                return (
                  <TouchableOpacity
                    key={index}
                    className="w-full py-3 px-4 rounded-2xl items-center justify-center flex-row gap-2 shadow-sm"
                    style={{
                      backgroundColor: isPrimary ? colors.cyan : colors.accentPill,
                      borderWidth: 1,
                      borderColor: isDestructive ? colors.red : colors.border,
                    }}
                    onPress={() => handleButtonPress(btn)}
                    activeOpacity={0.75}
                  >
                    {btn.icon && (
                      <Ionicons
                        name={btn.icon}
                        size={16}
                        color={isPrimary ? '#0F172A' : isDestructive ? colors.red : colors.textMain}
                      />
                    )}
                    <Text
                      className="text-xs font-bold"
                      style={{
                        color: isPrimary ? '#0F172A' : isDestructive ? colors.red : colors.textMain,
                      }}
                    >
                      {btn.text}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          ) : isDualButtons ? (
            /* Horizontal Dual Buttons */
            <View className="flex-row items-center gap-3 w-full pt-2">
              {buttons.map((btn, index) => {
                const isCancel = btn.style === 'cancel';
                const isDestructive = btn.style === 'destructive';
                const isPrimary = btn.style === 'default' || (!isCancel && !isDestructive);

                return (
                  <TouchableOpacity
                    key={index}
                    className="flex-1 py-3 px-3 rounded-2xl items-center justify-center shadow-sm"
                    style={{
                      backgroundColor: isPrimary ? colors.cyan : colors.accentPill,
                      borderWidth: 1,
                      borderColor: isDestructive ? colors.red : colors.border,
                    }}
                    onPress={() => handleButtonPress(btn)}
                    activeOpacity={0.75}
                  >
                    <Text
                      className="text-xs font-bold"
                      style={{
                        color: isPrimary ? '#0F172A' : isDestructive ? colors.red : colors.textMain,
                      }}
                    >
                      {btn.text}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          ) : (
            /* Single Primary Confirmation Button */
            <TouchableOpacity
              className="w-full py-3.5 rounded-2xl items-center justify-center shadow-sm mt-1"
              style={{ backgroundColor: colors.cyan }}
              onPress={() => handleButtonPress(buttons[0])}
              activeOpacity={0.85}
            >
              <Text className="text-xs font-extrabold" style={{ color: '#0F172A' }}>
                {buttons[0]?.text || 'OK'}
              </Text>
            </TouchableOpacity>
          )}
        </View>
      </View>
    </Modal>
  );
}

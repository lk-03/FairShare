import React, { useState } from 'react';
import {
  View,
  Modal,
  TouchableOpacity,
  TextInput,
  ActivityIndicator,
  useColorScheme,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { useRouter } from 'expo-router';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { Text } from '@/components/ui/Text';

interface JoinGroupModalProps {
  visible: boolean;
  onClose: () => void;
  onScanQr?: () => void;
}

export function JoinGroupModal({ visible, onClose, onScanQr }: JoinGroupModalProps) {
  const router = useRouter();
  const insets = useSafeAreaInsets();
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { joinCohortByInviteCode } = useExpenseStore();
  const [inviteCode, setInviteCode] = useState('');
  const [isJoining, setIsJoining] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');

  const handlePasteClipboard = async () => {
    try {
      const text = await Clipboard.getStringAsync();
      if (text) {
        const clean = text.replace(/^(fairshare:\/\/join\/|https?:\/\/[^\/]+\/join\/)/i, '').trim().toUpperCase();
        setInviteCode(clean);
        setErrorMessage('');
      }
    } catch {
      // Ignored
    }
  };

  const handleJoin = async () => {
    const clean = inviteCode
      .replace(/^(fairshare:\/\/join\/|https?:\/\/[^\/]+\/join\/)/i, '')
      .trim()
      .toUpperCase();

    if (!clean) {
      setErrorMessage('Please enter an invite code.');
      return;
    }

    setIsJoining(true);
    setErrorMessage('');

    try {
      const cohort = await joinCohortByInviteCode(clean);
      if (cohort) {
        setInviteCode('');
        onClose();
        showAlert('Joined Group', `Welcome to ${cohort.name}!`, [
          {
            text: 'Open Group',
            style: 'default',
            onPress: () => router.push(`/event/${cohort.id}` as any),
          },
        ]);
      } else {
        setErrorMessage(`Invite code "${clean}" was not found. Please verify with your group admin.`);
      }
    } catch (err) {
      setErrorMessage('Failed to join group. Please check your network connection.');
    } finally {
      setIsJoining(false);
    }
  };

  const handleScanQrPress = () => {
    onClose();
    if (onScanQr) {
      onScanQr();
    } else {
      router.push('/scan' as any);
    }
  };

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      statusBarTranslucent={true}
      onRequestClose={onClose}
    >
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        className="flex-1"
      >
        <View className={`flex-1 ${activeThemeClass} bg-black/60 justify-end`}>
          <TouchableOpacity
            className="flex-1"
            activeOpacity={1}
            onPress={onClose}
          />
          <View
            className="rounded-t-[32px] p-6 gap-4 border-t shadow-2xl"
            style={{
              backgroundColor: colors.surface,
              borderColor: colors.border,
              paddingBottom: Math.max(insets.bottom + 16, 32),
            }}
          >
            {/* Header */}
            <View className="flex-row items-center justify-between pb-1">
              <View className="flex-row items-center gap-2.5">
                <View
                  className="w-9 h-9 rounded-xl items-center justify-center border"
                  style={{ backgroundColor: `${colors.cyan}18`, borderColor: `${colors.cyan}35` }}
                >
                  <Ionicons name="enter-outline" size={20} color={colors.cyan} />
                </View>
                <View>
                  <Text className="text-lg font-black tracking-tight" style={{ color: colors.textMain }}>
                    Join Group
                  </Text>
                  <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                    Enter invite code or scan group QR
                  </Text>
                </View>
              </View>

              <TouchableOpacity
                onPress={onClose}
                className="w-8 h-8 rounded-full items-center justify-center border"
                style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
              >
                <Ionicons name="close" size={18} color={colors.textSecondary} />
              </TouchableOpacity>
            </View>

            {/* Invite Code Input Card */}
            <View
              className="p-4 rounded-3xl border gap-3 shadow-sm"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderColor: colors.border,
              }}
            >
              <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                GROUP INVITE CODE
              </Text>

              <View
                className="flex-row items-center px-3.5 rounded-2xl border"
                style={{
                  backgroundColor: colors.surface,
                  borderColor: errorMessage ? '#FB7185' : colors.border,
                }}
              >
                <Ionicons name="key-outline" size={18} color={colors.cyan} />
                <TextInput
                  value={inviteCode}
                  onChangeText={(val) => {
                    setInviteCode(val.toUpperCase());
                    if (errorMessage) setErrorMessage('');
                  }}
                  placeholder="e.g. GOA2026 or CC6868"
                  placeholderTextColor={colors.textSecondary}
                  autoCapitalize="characters"
                  autoCorrect={false}
                  maxLength={20}
                  className="flex-1 py-3.5 px-3 text-base font-mono font-bold"
                  style={{ color: colors.textMain }}
                />
                <TouchableOpacity
                  onPress={handlePasteClipboard}
                  className="px-2.5 py-1.5 rounded-xl border flex-row items-center gap-1"
                  style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
                  activeOpacity={0.75}
                >
                  <Ionicons name="clipboard-outline" size={14} color={colors.cyan} />
                  <Text className="text-[11px] font-bold" style={{ color: colors.cyan }}>
                    Paste
                  </Text>
                </TouchableOpacity>
              </View>

              {errorMessage ? (
                <View className="flex-row items-center gap-1.5 px-1">
                  <Ionicons name="alert-circle-outline" size={14} color="#FB7185" />
                  <Text className="text-xs font-semibold text-rose-400 flex-1">
                    {errorMessage}
                  </Text>
                </View>
              ) : null}

              {/* Join Button */}
              <TouchableOpacity
                onPress={handleJoin}
                disabled={isJoining || !inviteCode.trim()}
                className="h-13 py-3.5 rounded-2xl items-center justify-center flex-row gap-2 shadow-sm"
                style={{
                  backgroundColor: inviteCode.trim() ? colors.cyan : colors.accentPill,
                  opacity: isJoining ? 0.7 : 1,
                }}
                activeOpacity={0.85}
              >
                {isJoining ? (
                  <ActivityIndicator size="small" color="#0F172A" />
                ) : (
                  <>
                    <Text
                      className="text-sm font-black"
                      style={{ color: inviteCode.trim() ? '#0F172A' : colors.textSecondary }}
                    >
                      Join Group
                    </Text>
                    <Ionicons
                      name="arrow-forward"
                      size={16}
                      color={inviteCode.trim() ? '#0F172A' : colors.textSecondary}
                    />
                  </>
                )}
              </TouchableOpacity>
            </View>

            {/* Divider */}
            <View className="flex-row items-center gap-3 py-1">
              <View className="flex-1 h-px" style={{ backgroundColor: colors.border }} />
              <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
                OR
              </Text>
              <View className="flex-1 h-px" style={{ backgroundColor: colors.border }} />
            </View>

            {/* Scan QR Code Button */}
            <TouchableOpacity
              onPress={handleScanQrPress}
              className="py-4 px-4 rounded-2xl border flex-row items-center justify-between"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderColor: colors.border,
              }}
              activeOpacity={0.8}
            >
              <View className="flex-row items-center gap-3">
                <View
                  className="w-10 h-10 rounded-xl items-center justify-center border"
                  style={{ backgroundColor: `${colors.cyan}18`, borderColor: `${colors.cyan}35` }}
                >
                  <Ionicons name="qr-code-outline" size={20} color={colors.cyan} />
                </View>
                <View>
                  <Text className="text-sm font-extrabold" style={{ color: colors.textMain }}>
                    Scan QR Code
                  </Text>
                  <Text className="text-[11px] font-semibold" style={{ color: colors.textSecondary }}>
                    Use camera to scan group invite QR
                  </Text>
                </View>
              </View>
              <Ionicons name="chevron-forward" size={16} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

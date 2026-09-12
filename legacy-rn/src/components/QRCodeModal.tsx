import React, { useMemo, useState } from 'react';
import { View, Modal, TouchableOpacity, useColorScheme, Share } from 'react-native';
import QRCode from 'qrcode';
import { Ionicons } from '@expo/vector-icons';
import * as Clipboard from 'expo-clipboard';
import { useThemeStore, getActiveThemeClass, getThemePalette } from '@/store/useThemeStore';
import { Text } from '@/components/ui/Text';

import { EventCohort } from '@/types';

interface QRCodeModalProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  inviteCode?: string;
  cohort?: EventCohort | null;
  isNewGroup?: boolean;
  onContinue?: () => void;
}

export function QRCodeModal({
  visible,
  onClose,
  title: directTitle,
  inviteCode: directInviteCode,
  cohort,
  isNewGroup = false,
  onContinue,
}: QRCodeModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const title = cohort?.name || directTitle || 'FairShare Group';
  const inviteCode = cohort?.inviteCode || directInviteCode || '';

  const [copied, setCopied] = useState(false);
  const deepLink = `fairshare://join/${inviteCode}`;

  const handleCopyCode = async () => {
    try {
      await Clipboard.setStringAsync(inviteCode);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Ignored
    }
  };

  const handleShare = async () => {
    try {
      await Share.share({
        message: `Join my group "${title}" on FairShare using invite code: ${inviteCode}\n\nOr click: https://fairshare.app/join/${inviteCode}`,
        title: `Join ${title} on FairShare`,
      });
    } catch {
      // Ignored
    }
  };

  // Generate pure matrix modules (size x size array of 0s and 1s)
  const qrMatrix = useMemo(() => {
    try {
      const qr = QRCode.create(deepLink, { errorCorrectionLevel: 'M' });
      const moduleSize = qr.modules.size;
      const data = qr.modules.data;
      const matrix: boolean[][] = [];

      for (let r = 0; r < moduleSize; r++) {
        const row: boolean[] = [];
        for (let c = 0; c < moduleSize; c++) {
          row.push(Boolean(data[r * moduleSize + c]));
        }
        matrix.push(row);
      }
      return { matrix, moduleSize };
    } catch (e) {
      console.warn('Error generating QR matrix:', e);
      return null;
    }
  }, [deepLink]);

  const handleDone = () => {
    if (onContinue) {
      onContinue();
    } else {
      onClose();
    }
  };

  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={handleDone}>
      <View className={`flex-1 ${activeThemeClass} bg-black/60 items-center justify-center p-5`}>
        <TouchableOpacity
          className="absolute inset-0"
          activeOpacity={1}
          onPress={handleDone}
        />
        <View
          className="w-full max-w-[360px] rounded-3xl p-6 border shadow-2xl items-center gap-4"
          style={{
            backgroundColor: colors.surface,
            borderColor: colors.border,
          }}
        >
          {/* Header */}
          <View className="w-full flex-row items-center justify-between">
            <View className="flex-row items-center gap-2.5">
              <View
                className="w-9 h-9 rounded-xl items-center justify-center border"
                style={{ backgroundColor: `${colors.cyan}18`, borderColor: `${colors.cyan}35` }}
              >
                <Ionicons
                  name={isNewGroup ? 'checkmark-circle-outline' : 'qr-code-outline'}
                  size={20}
                  color={colors.cyan}
                />
              </View>
              <View className="flex-1 pr-2">
                <Text className="text-lg font-black tracking-tight" style={{ color: colors.textMain }} numberOfLines={1}>
                  {isNewGroup ? 'Group Created!' : title}
                </Text>
                <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                  {isNewGroup ? `Invite friends to join ${title}` : 'Invite members via QR or code'}
                </Text>
              </View>
            </View>
            <TouchableOpacity
              onPress={handleDone}
              className="w-8 h-8 rounded-full items-center justify-center border"
              style={{ backgroundColor: colors.accentPill, borderColor: colors.border }}
            >
              <Ionicons name="close" size={18} color={colors.textSecondary} />
            </TouchableOpacity>
          </View>

          {/* QR Code Canvas */}
          <View
            className="p-4 bg-white border rounded-2xl shadow-sm items-center justify-center"
            style={{ borderColor: colors.border }}
          >
            {qrMatrix ? (
              <View className="w-[190px] h-[190px] flex-col">
                {qrMatrix.matrix.map((row, rIdx) => (
                  <View key={rIdx} className="flex-1 flex-row">
                    {row.map((isDarkPixel, cIdx) => (
                      <View
                        key={cIdx}
                        className={`flex-1 ${isDarkPixel ? 'bg-slate-900' : 'bg-white'}`}
                      />
                    ))}
                  </View>
                ))}
              </View>
            ) : (
              <View className="w-[190px] h-[190px] items-center justify-center">
                <Text className="text-slate-400 text-xs">Generating QR...</Text>
              </View>
            )}
          </View>

          {/* Interactive Copy Code Box */}
          <View className="w-full gap-1.5">
            <Text
              className="text-[11px] font-bold uppercase tracking-wider text-center"
              style={{ color: colors.textSecondary }}
            >
              GROUP INVITE CODE
            </Text>

            <TouchableOpacity
              onPress={handleCopyCode}
              activeOpacity={0.8}
              className="w-full flex-row items-center justify-between p-3 px-4 rounded-2xl border"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderColor: copied ? '#34D399' : colors.border,
              }}
            >
              <View className="flex-row items-center gap-2">
                <Ionicons name="key-outline" size={18} color={colors.cyan} />
                <Text
                  className="text-base font-mono font-black tracking-widest"
                  style={{ color: colors.textMain }}
                >
                  {inviteCode}
                </Text>
              </View>

              <View
                className="flex-row items-center gap-1 py-1.5 px-3 rounded-xl border"
                style={{
                  backgroundColor: copied ? 'rgba(52, 211, 153, 0.15)' : `${colors.cyan}18`,
                  borderColor: copied ? 'rgba(52, 211, 153, 0.35)' : `${colors.cyan}35`,
                }}
              >
                <Ionicons
                  name={copied ? 'checkmark' : 'copy-outline'}
                  size={14}
                  color={copied ? '#34D399' : colors.cyan}
                />
                <Text
                  className="text-xs font-extrabold"
                  style={{ color: copied ? '#34D399' : colors.cyan }}
                >
                  {copied ? 'Copied' : 'Copy Code'}
                </Text>
              </View>
            </TouchableOpacity>
          </View>

          {/* Share Action Button & Done / Go to Group CTA */}
          <View className="w-full flex-row gap-2.5 pt-1">
            <TouchableOpacity
              className="flex-1 py-3.5 rounded-2xl border flex-row items-center justify-center gap-2 shadow-sm"
              style={{
                backgroundColor: isDark ? colors.accentPill : '#FFFFFF',
                borderColor: colors.border,
              }}
              onPress={handleShare}
              activeOpacity={0.8}
            >
              <Ionicons name="share-social-outline" size={18} color={colors.cyan} />
              <Text className="text-sm font-bold" style={{ color: colors.cyan }}>
                Share Invite
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              className="py-3.5 px-6 rounded-2xl items-center justify-center shadow-sm flex-row gap-1.5"
              style={{ backgroundColor: colors.cyan }}
              onPress={handleDone}
              activeOpacity={0.85}
            >
              <Text className="text-slate-950 font-extrabold text-sm">
                {isNewGroup ? 'Go to Group' : 'Done'}
              </Text>
              {isNewGroup && (
                <Ionicons name="arrow-forward" size={16} color="#0F172A" />
              )}
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
}

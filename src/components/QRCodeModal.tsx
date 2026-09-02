import React, { useMemo } from 'react';
import { View, Modal, TouchableOpacity, useColorScheme } from 'react-native';
import QRCode from 'qrcode';
import { useThemeStore, getActiveThemeClass } from '@/store/useThemeStore';
import { Text } from '@/components/ui/Text';

interface QRCodeModalProps {
  visible: boolean;
  onClose: () => void;
  title: string;
  inviteCode: string;
}

export function QRCodeModal({ visible, onClose, title, inviteCode }: QRCodeModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(themeBase, colorScheme, systemScheme);

  const deepLink = `fairshare://join/${inviteCode}`;

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

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose}>
      <View className={`flex-1 ${activeThemeClass} bg-black/50 items-center justify-center p-5`}>
        <TouchableOpacity
          className="absolute inset-0"
          activeOpacity={1}
          onPress={onClose}
        />
        <View className="w-full max-w-[340px] rounded-3xl p-6 bg-surface border border-surface shadow-xl items-center gap-4">
          <Text className="text-xl font-extrabold text-main text-center">Join {title}</Text>
          <Text className="text-xs text-secondary text-center">
            Scan QR code or use code:{' '}
            <Text className="font-extrabold text-main">{inviteCode}</Text>
          </Text>

          <View className="p-4 bg-white border border-slate-200 rounded-2xl shadow-sm">
            {qrMatrix ? (
              <View className="w-[200px] h-[200px] flex-col">
                {qrMatrix.matrix.map((row, rIdx) => (
                  <View key={rIdx} className="flex-1 flex-row">
                    {row.map((isDark, cIdx) => (
                      <View
                        key={cIdx}
                        className={`flex-1 ${isDark ? 'bg-slate-900' : 'bg-white'}`}
                      />
                    ))}
                  </View>
                ))}
              </View>
            ) : (
              <View className="w-[200px] h-[200px] items-center justify-center">
                <Text className="text-slate-400 text-xs">Generating QR...</Text>
              </View>
            )}
          </View>

          <TouchableOpacity
            className="w-full bg-main py-3.5 rounded-2xl items-center mt-2 shadow-sm"
            onPress={onClose}
          >
            <Text className="text-screen font-bold text-sm">Done</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

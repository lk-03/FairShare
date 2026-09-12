import React, { useState, useEffect } from 'react';
import { StyleSheet, View, TouchableOpacity, ActivityIndicator } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';
import { showAlert } from '@/store/useAlertStore';
import { Text } from '@/components/ui/Text';
import { JoinGroupModal } from '@/components/JoinGroupModal';

export default function ScanScreen() {
  const router = useRouter();
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [codeModalVisible, setCodeModalVisible] = useState(false);

  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme);
  const { joinCohortByInviteCode } = useExpenseStore();

  useEffect(() => {
    if (!permission?.granted) {
      requestPermission();
    }
  }, [permission]);

  const handleBarcodeScanned = async ({ data }: { data: string }) => {
    if (scanned || isProcessing) return;
    setScanned(true);
    setIsProcessing(true);

    let cleanCode = data
      .replace(/^(fairshare:\/\/join\/|https?:\/\/[^\/]+\/join\/)/i, '')
      .trim()
      .toUpperCase();

    const cohort = await joinCohortByInviteCode(cleanCode);
    setIsProcessing(false);

    if (cohort) {
      showAlert('Joined Group', `Welcome to ${cohort.name}!`, [
        {
          text: 'Open Group',
          style: 'default',
          onPress: () => router.replace(`/event/${cohort.id}` as any),
        },
      ]);
    } else {
      showAlert('Invalid QR Code', `Invite code "${cleanCode}" was not found.`, [
        { text: 'Try Again', style: 'default', onPress: () => setScanned(false) },
      ]);
    }
  };

  if (!permission?.granted) {
    return (
      <View className="flex-1 bg-slate-950 justify-center items-center p-6 gap-5">
        <View
          className="w-16 h-16 rounded-full items-center justify-center border mb-2"
          style={{ backgroundColor: `${colors.cyan}18`, borderColor: `${colors.cyan}40` }}
        >
          <Ionicons name="camera-outline" size={32} color={colors.cyan} />
        </View>
        <Text className="text-white text-center text-lg font-bold">
          Camera Permission Needed
        </Text>
        <Text className="text-slate-400 text-center text-xs px-4">
          FairShare requires camera access to scan group invite QR codes.
        </Text>
        <View className="flex-row gap-3 mt-2">
          <TouchableOpacity
            className="py-3 px-5 rounded-2xl border border-white/20"
            onPress={() => router.back()}
          >
            <Text className="text-white font-bold text-sm">Cancel</Text>
          </TouchableOpacity>
          <TouchableOpacity
            className="py-3 px-6 rounded-2xl"
            style={{ backgroundColor: colors.cyan }}
            onPress={requestPermission}
          >
            <Text className="text-slate-950 font-bold text-sm">Grant Permission</Text>
          </TouchableOpacity>
        </View>
      </View>
    );
  }

  return (
    <View className="flex-1 bg-black">
      <CameraView
        style={StyleSheet.absoluteFill}
        onBarcodeScanned={scanned ? undefined : handleBarcodeScanned}
        barcodeScannerSettings={{
          barcodeTypes: ['qr'],
        }}
      />

      <View className="flex-1 justify-between py-12 px-6">
        {/* Top Header */}
        <View className="flex-row items-center justify-between pt-4">
          <TouchableOpacity
            className="w-10 h-10 rounded-full bg-black/50 items-center justify-center border border-white/20"
            onPress={() => router.back()}
          >
            <Ionicons name="close" size={22} color="#FFFFFF" />
          </TouchableOpacity>
          <Text className="text-white text-base font-black">Scan Group QR</Text>
          <View className="w-10" />
        </View>

        {/* Viewfinder Target */}
        <View className="items-center justify-center">
          <View
            className="w-64 h-64 border-2 rounded-3xl bg-black/15 items-center justify-center relative"
            style={{ borderColor: colors.cyan }}
          >
            {isProcessing ? (
              <View className="items-center gap-3">
                <ActivityIndicator size="large" color={colors.cyan} />
                <Text className="text-white font-bold text-xs">Joining group...</Text>
              </View>
            ) : null}
          </View>
          <Text className="text-white/80 text-xs font-semibold mt-4 text-center">
            Point camera at another FairShare user's group QR code
          </Text>
        </View>

        {/* Bottom Actions */}
        <View className="gap-3 items-center pb-4">
          <TouchableOpacity
            className="py-3 px-6 rounded-2xl border flex-row items-center gap-2 bg-black/60"
            style={{ borderColor: `${colors.cyan}60` }}
            onPress={() => setCodeModalVisible(true)}
          >
            <Ionicons name="key-outline" size={18} color={colors.cyan} />
            <Text className="font-bold text-sm" style={{ color: colors.cyan }}>
              Enter Code Instead
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      <JoinGroupModal
        visible={codeModalVisible}
        onClose={() => setCodeModalVisible(false)}
        onScanQr={() => {
          setCodeModalVisible(false);
          setScanned(false);
        }}
      />
    </View>
  );
}

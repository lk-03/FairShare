import React, { useState, useEffect } from 'react';
import { StyleSheet, View, TouchableOpacity } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';
import { showAlert } from '@/store/useAlertStore';
import { Text } from '@/components/ui/Text';

export default function ScanScreen() {
  const router = useRouter();
  const [permission, requestPermission] = useCameraPermissions();
  const [scanned, setScanned] = useState(false);

  const { joinCohortByInviteCode } = useExpenseStore();

  useEffect(() => {
    if (!permission?.granted) {
      requestPermission();
    }
  }, [permission]);

  const handleBarcodeScanned = async ({ data }: { data: string }) => {
    if (scanned) return;
    setScanned(true);

    let inviteCode = data;
    if (data.includes('fairshare://join/')) {
      inviteCode = data.split('fairshare://join/')[1];
    }

    const cohort = await joinCohortByInviteCode(inviteCode);

    if (cohort) {
      showAlert('Success!', `Joined ${cohort.name}`, [
        {
          text: 'Open Event',
          style: 'default',
          onPress: () => router.replace(`/event/${cohort.id}` as any),
        },
      ]);
    } else {
      showAlert('Invalid QR Code', `Invite code "${inviteCode}" not found.`, [
        { text: 'Try Again', style: 'default', onPress: () => setScanned(false) },
      ]);
    }
  };

  if (!permission?.granted) {
    return (
      <View className="flex-1 bg-black justify-center items-center p-6 gap-5">
        <Text className="text-white text-center text-base">
          Camera permission required to scan QR code.
        </Text>
        <TouchableOpacity
          className="bg-white py-3.5 px-6 rounded-2xl"
          onPress={requestPermission}
        >
          <Text className="text-slate-900 font-bold text-sm">Grant Permission</Text>
        </TouchableOpacity>
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

      <View className="flex-1 justify-between items-center py-16 px-6">
        <Text className="text-white text-lg font-bold">Scan FairShare QR Code</Text>
        <View className="w-64 h-64 border-4 border-white/80 rounded-3xl bg-transparent" />
        
        <View className="gap-4 items-center">
          <TouchableOpacity
            className="bg-white/20 px-4 py-2 rounded-xl"
            onPress={() => {
              const code = 'GOA2026';
              handleBarcodeScanned({ data: code });
            }}
          >
            <Text className="text-white text-xs font-semibold">Simulate Scan (GOA2026)</Text>
          </TouchableOpacity>

          <TouchableOpacity
            className="bg-white/10 px-6 py-2.5 rounded-full"
            onPress={() => router.back()}
          >
            <Text className="text-white font-bold text-sm">Cancel</Text>
          </TouchableOpacity>
        </View>
      </View>
    </View>
  );
}

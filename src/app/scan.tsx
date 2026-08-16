import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, TouchableOpacity, Alert } from 'react-native';
import { CameraView, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { useExpenseStore } from '@/store/useExpenseStore';

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

  const handleBarcodeScanned = ({ data }: { data: string }) => {
    if (scanned) return;
    setScanned(true);

    let inviteCode = data;
    if (data.includes('fairshare://join/')) {
      inviteCode = data.split('fairshare://join/')[1];
    }

    const cohort = joinCohortByInviteCode(inviteCode);

    if (cohort) {
      Alert.alert('Success!', `Joined ${cohort.name}`, [
        {
          text: 'Open Event',
          onPress: () => router.replace(`/event/${cohort.id}` as any),
        },
      ]);
    } else {
      Alert.alert('Invalid QR Code', `Invite code "${inviteCode}" not found.`, [
        { text: 'Try Again', onPress: () => setScanned(false) },
      ]);
    }
  };

  if (!permission?.granted) {
    return (
      <View style={styles.container}>
        <Text style={styles.text}>Camera permission required to scan QR code.</Text>
        <TouchableOpacity style={styles.button} onPress={requestPermission}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <CameraView
        style={StyleSheet.absoluteFill}
        onBarcodeScanned={scanned ? undefined : handleBarcodeScanned}
        barcodeScannerSettings={{
          barcodeTypes: ['qr'],
        }}
      />

      <View style={styles.overlay}>
        <Text style={styles.headerTitle}>Scan FairShare QR Code</Text>
        <View style={styles.scanBox} />
        
        <View style={styles.manualBox}>
          <TouchableOpacity
            style={styles.manualBtn}
            onPress={() => {
              const code = 'GOA2026';
              handleBarcodeScanned({ data: code });
            }}
          >
            <Text style={styles.manualText}>Simulate Scan (GOA2026)</Text>
          </TouchableOpacity>
        </View>

        <TouchableOpacity style={styles.cancelBtn} onPress={() => router.back()}>
          <Text style={styles.cancelText}>Cancel</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  text: {
    color: '#FFF',
    fontSize: 16,
    textAlign: 'center',
    marginBottom: 20,
    paddingHorizontal: 20,
  },
  button: {
    backgroundColor: '#6366F1',
    paddingHorizontal: 20,
    paddingVertical: 12,
    borderRadius: 10,
  },
  buttonText: {
    color: '#FFF',
    fontWeight: '700',
  },
  overlay: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 60,
  },
  headerTitle: {
    color: '#FFF',
    fontSize: 18,
    fontWeight: '700',
  },
  scanBox: {
    width: 250,
    height: 250,
    borderWidth: 3,
    borderColor: '#6366F1',
    borderRadius: 20,
    backgroundColor: 'transparent',
  },
  cancelBtn: {
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
    paddingHorizontal: 24,
    paddingVertical: 10,
    borderRadius: 20,
  },
  cancelText: {
    color: '#FFF',
    fontWeight: '700',
  },
  manualBox: {
    alignItems: 'center',
  },
  manualBtn: {
    backgroundColor: '#6366F1',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 12,
  },
  manualText: {
    color: '#FFF',
    fontWeight: '700',
    fontSize: 13,
  },
});

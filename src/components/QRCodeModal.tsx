import React, { useMemo } from 'react';
import { StyleSheet, View, Text, Modal, TouchableOpacity } from 'react-native';
import QRCode from 'qrcode';
import { useTheme } from '@/hooks/use-theme';

interface QRCodeModalProps {
  visible: boolean;
  onClose: () => void;
  title: string;
  inviteCode: string;
}

export function QRCodeModal({ visible, onClose, title, inviteCode }: QRCodeModalProps) {
  const theme = useTheme();

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
      <View style={styles.backdrop}>
        <View style={[styles.card, { backgroundColor: theme.backgroundElement }]}>
          <Text style={[styles.title, { color: theme.text }]}>Join {title}</Text>
          <Text style={[styles.subtitle, { color: theme.textSecondary }]}>
            Scan QR code or use code: <Text style={styles.codeHighlight}>{inviteCode}</Text>
          </Text>

          <View style={styles.qrContainer}>
            {qrMatrix ? (
              <View style={styles.matrixBox}>
                {qrMatrix.matrix.map((row, rIdx) => (
                  <View key={rIdx} style={styles.matrixRow}>
                    {row.map((isDark, cIdx) => (
                      <View
                        key={cIdx}
                        style={[
                          styles.pixel,
                          { backgroundColor: isDark ? '#1E1E24' : '#FFFFFF' },
                        ]}
                      />
                    ))}
                  </View>
                ))}
              </View>
            ) : (
              <View style={styles.qrPlaceholder}>
                <Text style={{ color: theme.textSecondary }}>Generating QR...</Text>
              </View>
            )}
          </View>

          <TouchableOpacity style={styles.closeBtn} onPress={onClose}>
            <Text style={styles.closeBtnText}>Done</Text>
          </TouchableOpacity>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 20,
  },
  card: {
    width: '100%',
    maxWidth: 340,
    borderRadius: 20,
    padding: 24,
    alignItems: 'center',
    gap: 16,
  },
  title: {
    fontSize: 20,
    fontWeight: '700',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 14,
    textAlign: 'center',
  },
  codeHighlight: {
    fontWeight: '800',
    color: '#6366F1',
  },
  qrContainer: {
    padding: 14,
    backgroundColor: '#FFFFFF',
    borderRadius: 16,
  },
  matrixBox: {
    width: 200,
    height: 200,
    flexDirection: 'column',
  },
  matrixRow: {
    flex: 1,
    flexDirection: 'row',
  },
  pixel: {
    flex: 1,
  },
  qrPlaceholder: {
    width: 200,
    height: 200,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeBtn: {
    backgroundColor: '#6366F1',
    width: '100%',
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  closeBtnText: {
    color: '#FFF',
    fontWeight: '700',
    fontSize: 15,
  },
});

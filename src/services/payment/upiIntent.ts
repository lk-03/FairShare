import { Linking, Platform } from 'react-native';
import QRCode from 'qrcode';
import { UPIPaymentConfig } from '@/types';

/**
 * Builds standard OS-level UPI intent deep link URI
 * Scheme: upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...
 * Note is sanitized to alphanumeric characters only to prevent bank risk policy blocks.
 */
export function buildUPIIntentURL(config: UPIPaymentConfig): string {
  const { vpaId = '', payeeName = '', amount = 0, currency = 'INR', note = '' } = config;

  const formattedAmount = Number(amount || 0).toFixed(2);
  const cleanName = String(payeeName || 'Payee').trim();
  const encodedName = encodeURIComponent(cleanName);
  const cleanNote = String(note || 'FairShare')
    .replace(/[^a-zA-Z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim() || 'FairShare';
  const encodedNote = encodeURIComponent(cleanNote);
  const cleanVpa = String(vpaId || '').trim();

  return `upi://pay?pa=${cleanVpa}&pn=${encodedName}&am=${formattedAmount}&cu=${currency}&tn=${encodedNote}`;
}

/**
 * Generates a pure boolean matrix for rendering UPI QR codes natively in React Native
 * without any HTML canvas or DOM dependencies.
 */
export function generateUPIMatrix(config: UPIPaymentConfig): { matrix: boolean[][]; moduleSize: number } {
  const url = buildUPIIntentURL(config);
  const qr = QRCode.create(url, { errorCorrectionLevel: 'M' });
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
}

/**
 * Generates a base64 PNG data URL for a scannable UPI QR code (Node / Web environments).
 */
export async function generateUPIQRCode(config: UPIPaymentConfig): Promise<string> {
  const url = buildUPIIntentURL(config);
  return QRCode.toDataURL(url, {
    width: 256,
    margin: 1,
    color: {
      dark: '#000000',
      light: '#FFFFFF',
    },
  });
}

/**
 * Programmatically triggers OS-level UPI intent redirection
 * Redirects user to GPay, PhonePe, Paytm, or preferred installed UPI app.
 */
export async function launchUPIIntent(config: UPIPaymentConfig): Promise<{ success: boolean; message?: string }> {
  if (!config.vpaId || !config.vpaId.includes('@')) {
    return {
      success: false,
      message: 'Invalid Payee UPI ID (VPA). Please update profile with a valid UPI ID (e.g. name@upi).',
    };
  }

  const url = buildUPIIntentURL(config);

  try {
    const supported = await Linking.canOpenURL(url);

    if (supported || Platform.OS === 'android') {
      await Linking.openURL(url);
      return { success: true };
    } else {
      return {
        success: false,
        message: 'No supported UPI app found. Please copy the VPA ID to pay manually.',
      };
    }
  } catch (err: any) {
    console.warn('Error launching UPI Intent:', err);
    return {
      success: false,
      message: err?.message || 'Could not launch UPI payment app.',
    };
  }
}

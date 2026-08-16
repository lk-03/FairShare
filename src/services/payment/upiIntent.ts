import { Linking, Platform } from 'react-native';
import { UPIPaymentConfig } from '@/types';

/**
 * Builds standard OS-level UPI intent deep link URI
 * Scheme: upi://pay?pa=...&pn=...&am=...&cu=INR&tn=...
 */
export function buildUPIIntentURL(config: UPIPaymentConfig): string {
  const { vpaId, payeeName, amount, currency = 'INR', note } = config;

  const formattedAmount = amount.toFixed(2);
  const encodedName = encodeURIComponent(payeeName.trim());
  const encodedNote = encodeURIComponent((note || '').trim() || 'FairShare Settlement');

  return `upi://pay?pa=${vpaId.trim()}&pn=${encodedName}&am=${formattedAmount}&cu=${currency}&tn=${encodedNote}`;
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

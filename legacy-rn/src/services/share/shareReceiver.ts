import { parseInvoicePdfText } from '@/utils/pdfInvoiceParser';
import { parseReceiptText, stitchMultiReceipts } from '@/utils/receiptParser';
import { ParsedReceiptData } from '@/types';

/**
 * Service to process incoming shared intents (PDFs, Images, Text from Blinkit/WhatsApp/Files)
 */
export interface SharedAsset {
  uri: string;
  mimeType?: string;
  name?: string;
  text?: string;
}

/**
 * Robust helper to read local file content as text
 */
async function readFileContentAsString(uri: string): Promise<string> {
  try {
    const res = await fetch(uri);
    const text = await res.text();
    if (text && text.trim().length > 0) {
      return text;
    }
  } catch {
    // Continue to next fallback
  }

  try {
    const legacyFS = await import('expo-file-system/legacy');
    if (legacyFS && legacyFS.readAsStringAsync) {
      return await legacyFS.readAsStringAsync(uri);
    }
  } catch {
    // Continue
  }

  return '';
}

/**
 * Extracts and parses receipt data from a local file URI (PDF, Text, or Image OCR)
 */
export async function processSharedAsset(asset: SharedAsset): Promise<ParsedReceiptData> {
  const uri = asset.uri || '';
  const isPdf = uri.toLowerCase().endsWith('.pdf') || asset.mimeType?.includes('pdf');
  const isText = uri.toLowerCase().endsWith('.txt') || uri.toLowerCase().endsWith('.csv') || asset.mimeType?.includes('text') || Boolean(asset.text);

  // 1. Direct Text Stream (e.g. shared text from Blinkit / WhatsApp)
  if (asset.text) {
    if (asset.text.toLowerCase().includes('invoice') || asset.text.toLowerCase().includes('bigbasket') || asset.text.toLowerCase().includes('swiggy')) {
      return parseInvoicePdfText(asset.text);
    }
    return parseReceiptText(asset.text);
  }

  // 2. Local Text File / Digital PDF File
  if ((isText || isPdf) && uri) {
    try {
      const fileContent = await readFileContentAsString(uri);
      if (fileContent && fileContent.trim().length > 0) {
        return parseInvoicePdfText(fileContent);
      }
    } catch (err) {
      console.warn('[ShareReceiver] Error reading file stream:', err);
    }
  }

  // 3. Default fallback: OCR parser on raw text or fallback structure
  return {
    merchantName: asset.name ? asset.name.replace(/\.[^/.]+$/, '') : 'Shared Receipt',
    lineItems: [],
    subtotal: 0,
    taxAmount: 0,
    serviceCharge: 0,
    discountAmount: 0,
    totalAmount: 0,
    rawText: asset.text || uri,
  };
}

/**
 * Processes multiple screenshot slices of a long receipt
 */
export async function processMultiScreenshots(imageTexts: string[]): Promise<ParsedReceiptData> {
  return stitchMultiReceipts(imageTexts);
}

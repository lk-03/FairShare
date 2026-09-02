export interface ParsedReceiptItem {
  name: string;
  quantity: number;
  price: number;
}

export interface ParsedReceiptData {
  merchantName: string;
  date: string;
  category: 'groceries' | 'dining' | 'travel' | 'entertainment' | 'shopping' | 'utilities' | 'general';
  items: ParsedReceiptItem[];
  subtotal: number;
  tax: number;
  discount: number;
  totalAmount: number;
  rawText?: string;
  source: 'gemini_vision' | 'local_ocr';
}

const GEMINI_API_KEY = process.env.EXPO_PUBLIC_GEMINI_API_KEY || '';

/**
 * Preprocesses and enhances the receipt image for optimal OCR clarity & fast transmission.
 * Resizes to 1400px width and compresses to high-quality JPEG base64.
 */
export async function preprocessReceiptImage(imageUri: string): Promise<{ base64: string; uri: string }> {
  try {
    const ImageManipulator = require('expo-image-manipulator');
    const result = await ImageManipulator.manipulateAsync(
      imageUri,
      [{ resize: { width: 1400 } }],
      {
        compress: 0.85,
        format: ImageManipulator.SaveFormat?.JPEG || 'jpeg',
        base64: true,
      }
    );
    return {
      base64: result.base64 || '',
      uri: result.uri,
    };
  } catch (err) {
    console.warn('[GeminiVision] Image preprocessing fallback:', err);
    return { base64: '', uri: imageUri };
  }
}

/**
 * Uses Google Gemini 2.0 / 1.5 Flash Vision to parse receipt / invoice with zero latency and structured JSON.
 */
export async function parseReceiptWithGemini(
  imageUriOrBase64: string,
  providedBase64?: string
): Promise<ParsedReceiptData | null> {
  const apiKey = process.env.EXPO_PUBLIC_GEMINI_API_KEY || GEMINI_API_KEY;

  let base64Data = providedBase64 || '';
  if (!base64Data && imageUriOrBase64.startsWith('file://')) {
    const processed = await preprocessReceiptImage(imageUriOrBase64);
    base64Data = processed.base64;
  } else if (!base64Data && !imageUriOrBase64.startsWith('http')) {
    base64Data = imageUriOrBase64.replace(/^data:image\/\w+;base64,/, '');
  }

  if (!base64Data || !apiKey || apiKey.includes('placeholder')) {
    return null;
  }

  const systemPrompt = `You are a high-accuracy Receipt & Invoice OCR Parser for the FairShare group expense splitter.
Analyze this receipt or invoice carefully.
Extract:
1. "merchantName": The store, restaurant, or vendor name (e.g. "Blinkit", "Swiggy Instamart", "Subway", "Toit", "DMart").
2. "date": Transaction date formatted as YYYY-MM-DD (or today's date if omitted).
3. "category": One of ["groceries", "dining", "travel", "entertainment", "shopping", "utilities", "general"].
4. "items": Array of item objects with "name" (clean product title), "quantity" (number, default 1), and "price" (total item cost).
5. "subtotal": Sum of items before tax/discounts.
6. "tax": GST, VAT, service tax, or tip total.
7. "discount": Total discount or coupon deductions (positive number).
8. "totalAmount": Grand total amount paid.

Return ONLY valid JSON matching this exact structure without markdown or backticks:
{
  "merchantName": "Store Name",
  "date": "2026-08-30",
  "category": "dining",
  "items": [
    {"name": "Paneer Butter Masala", "quantity": 1, "price": 280},
    {"name": "Butter Roti", "quantity": 4, "price": 120}
  ],
  "subtotal": 400,
  "tax": 20,
  "discount": 0,
  "totalAmount": 420
}`;

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                { text: systemPrompt },
                {
                  inline_data: {
                    mime_type: 'image/jpeg',
                    data: base64Data,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: 'application/json',
          },
        }),
      }
    );

    if (!response.ok) {
      const errText = await response.text();
      console.warn('[GeminiVision] API error response:', response.status, errText);
      return null;
    }

    const resJson = await response.json();
    const rawContent = resJson.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!rawContent) return null;

    const cleaned = rawContent.replace(/```json/g, '').replace(/```/g, '').trim();
    const parsed = JSON.parse(cleaned);

    if (!Array.isArray(parsed.items) || parsed.items.length === 0) {
      return null;
    }

    const safeItems: ParsedReceiptItem[] = parsed.items.map((it: any) => ({
      name: String(it.name || 'Item').trim(),
      quantity: Number(it.quantity) > 0 ? Number(it.quantity) : 1,
      price: Number(it.price) > 0 ? Number(it.price) : 0,
    }));

    const calculatedSubtotal = safeItems.reduce((sum, it) => sum + it.price, 0);
    const totalAmount = Number(parsed.totalAmount) || calculatedSubtotal;
    const tax = Number(parsed.tax) || 0;
    const discount = Number(parsed.discount) || 0;
    const subtotal = Number(parsed.subtotal) || calculatedSubtotal;

    return {
      merchantName: String(parsed.merchantName || 'Receipt Expense').trim(),
      date: parsed.date || new Date().toISOString().split('T')[0],
      category: parsed.category || 'general',
      items: safeItems,
      subtotal,
      tax,
      discount,
      totalAmount,
      source: 'gemini_vision',
    };
  } catch (err) {
    console.warn('[GeminiVision] Parsing failed, falling back:', err);
    return null;
  }
}

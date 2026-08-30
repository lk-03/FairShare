import { LineItem, LineItemAssignment, ParsedReceiptData, ItemSplitType } from '@/types';
import { parseReceiptWithGemini } from '@/services/ai/geminiVisionService';

/**
 * Parses receipt image using Google Gemini Flash AI Vision with fallback to local regex parser
 */
export async function parseReceiptImage(
  imageUriOrBase64: string,
  rawOcrTextFallback?: string
): Promise<ParsedReceiptData> {
  try {
    const aiResult = await parseReceiptWithGemini(imageUriOrBase64);
    if (aiResult && aiResult.items.length > 0) {
      return {
        merchantName: aiResult.merchantName,
        date: aiResult.date,
        currency: 'INR',
        lineItems: aiResult.items.map((it) => ({
          title: it.name,
          quantity: it.quantity,
          price: it.price,
        })),
        subtotal: aiResult.subtotal,
        taxAmount: aiResult.tax,
        serviceCharge: 0,
        discountAmount: aiResult.discount,
        totalAmount: aiResult.totalAmount,
        rawText: `[AI Parsed via Gemini Vision]\nMerchant: ${aiResult.merchantName}\nItems: ${aiResult.items.length}`,
      };
    }
  } catch (err) {
    console.warn('[ReceiptParser] Gemini AI parsing error, using local fallback:', err);
  }

  return parseReceiptText(rawOcrTextFallback || '');
}
export function parseReceiptText(text: string): ParsedReceiptData {
  if (!text || typeof text !== 'string') {
    return {
      lineItems: [],
      subtotal: 0,
      taxAmount: 0,
      serviceCharge: 0,
      discountAmount: 0,
      totalAmount: 0,
      rawText: '',
    };
  }

  const rawLines = text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0);

  let merchantName: string | undefined;
  let date: string | undefined;
  let currency = 'INR';
  const extractedItems: Array<{ title: string; quantity: number; price: number }> = [];
  let subtotal = 0;
  let taxAmount = 0;
  let serviceCharge = 0;
  let discountAmount = 0;
  let totalAmount = 0;

  // Patterns to identify system / header / footer lines
  const dateRegex = /\b(\d{1,2}[-\/.]\d{1,2}[-\/.]\d{2,4}|\d{4}[-\/.]\d{1,2}[-\/.]\d{1,2})\b/;
  const taxRegex = /(?:cgst|sgst|igst|gst|vat|sales\s*tax|tax)\b/i;
  const serviceChargeRegex = /(?:service\s*charge|staff\s*tip|gratuity|delivery\s*(?:partner\s*fee|fee|charge)|handling\s*(?:fee|charge)|platform\s*fee|rain\s*surge|surge\s*fee|packing\s*charge)\b/i;
  const discountRegex = /(?:discount|promo|coupon|off|zomato|swiggy|voucher)\b/i;
  const totalRegex = /(?:grand\s*total|net\s*total|net\s*amount|total\s*amount|total|total\s*paid|amount\s*payable|balance\s*due)\b/i;
  const subtotalRegex = /(?:sub\s*total|item\s*total|items\s*total|gross\s*total)\b/i;
  const ignoreRegex = /(?:invoice|bill\s*(?:no|#)?|table\s*(?:no|#|:)?|order\s*(?:no|#|:)?|cashier|terminal|fssai|gstin|pan|thank\s*you|visit\s*again|wifi|password|tel|phone|ph:)/i;

  // Helper to extract numerical price from a line
  const extractPrice = (line: string): number | null => {
    // Match trailing decimal or integer numbers, e.g. "380.00", "420", "1,450.50"
    const matches = line.match(/(?:₹|Rs\.?|INR|\$)?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*$/i);
    if (matches && matches[1]) {
      const numStr = matches[1].replace(/,/g, '');
      const parsed = parseFloat(numStr);
      if (!isNaN(parsed) && parsed > 0) {
        return parsed;
      }
    }
    return null;
  };

  // Helper to clean title
  const cleanTitle = (line: string): string => {
    return line
      .replace(/(?:₹|Rs\.?|INR|\$)?\s*[0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?\s*$/i, '') // remove price at end
      .replace(/^[0-9]+[\.\)\-\s]+/, '') // remove leading item numbers
      .replace(/^\d+\s*(?:x|\*)\s*/i, '') // remove leading quantity
      .replace(/[\s\-–—:]+$/g, '') // remove trailing separators / hyphens
      .replace(/^[\s\-–—:]+/g, '') // remove leading separators
      .trim();
  };

  // Helper to extract quantity
  const extractQty = (line: string): number => {
    const qtyMatch = line.match(/^(\d+)\s*(?:x|\*|nos|qty)?\s+/i) || line.match(/\bqty:?\s*(\d+)\b/i);
    if (qtyMatch && qtyMatch[1]) {
      const q = parseInt(qtyMatch[1], 10);
      if (q > 0 && q < 100) return q;
    }
    return 1;
  };

  for (let i = 0; i < rawLines.length; i++) {
    const line = rawLines[i];

    // Detect merchant name from very first non-ignored line
    if (!merchantName && i < 4 && !ignoreRegex.test(line) && !dateRegex.test(line) && line.length > 2 && line.length < 40) {
      if (!extractPrice(line) && !totalRegex.test(line)) {
        merchantName = line;
        continue;
      }
    }

    // Detect date
    if (!date) {
      const dateMatch = line.match(dateRegex);
      if (dateMatch) {
        date = dateMatch[1];
      }
    }

    // Check for currency
    if (line.includes('$')) currency = 'USD';
    else if (line.includes('₹') || /rs\.?|inr/i.test(line)) currency = 'INR';

    const price = extractPrice(line);

    // 1. Check for Subtotal
    if (subtotalRegex.test(line)) {
      if (price !== null) {
        subtotal = price;
      }
      continue;
    }

    // 2. Check for Total
    if (totalRegex.test(line)) {
      if (price !== null) {
        totalAmount = price;
      }
      continue;
    }

    // 3. Check for Taxes (GST, CGST, SGST, VAT)
    if (taxRegex.test(line)) {
      if (price !== null) {
        taxAmount += price;
      }
      continue;
    }

    // 4. Check for Service Charge / Tips / Delivery
    if (serviceChargeRegex.test(line)) {
      if (price !== null) {
        serviceCharge += price;
      }
      continue;
    }

    // 5. Check for Discounts
    if (discountRegex.test(line)) {
      if (price !== null) {
        discountAmount += Math.abs(price);
      }
      continue;
    }

    // 6. Ignore metadata lines
    if (ignoreRegex.test(line)) {
      continue;
    }

    // 7. Regular Line Item
    if (price !== null && price > 0) {
      const title = cleanTitle(line);
      const quantity = extractQty(line);

      if (title.length > 1 && !/total|subtotal|tax|discount|change|cash/i.test(title)) {
        extractedItems.push({
          title,
          quantity,
          price,
        });
      }
    }
  }

  // Calculate items sum
  const itemsSum = extractedItems.reduce((sum, item) => sum + item.price, 0);

  if (subtotal === 0) {
    subtotal = itemsSum;
  }

  if (totalAmount === 0) {
    totalAmount = Math.max(0, subtotal + taxAmount + serviceCharge - discountAmount);
  }

  return {
    merchantName: merchantName || 'Receipt',
    date,
    currency,
    lineItems: extractedItems,
    subtotal: Math.round(subtotal * 100) / 100,
    taxAmount: Math.round(taxAmount * 100) / 100,
    serviceCharge: Math.round(serviceCharge * 100) / 100,
    discountAmount: Math.round(discountAmount * 100) / 100,
    totalAmount: Math.round(totalAmount * 100) / 100,
    rawText: text,
  };
}

/**
 * Computes individual member splits from line items and proportional taxes/discounts.
 */
export function calculateItemizedSplits(
  lineItems: LineItem[],
  extras: {
    subtotal: number;
    taxAmount: number;
    serviceCharge: number;
    discountAmount: number;
    totalAmount: number;
  },
  allMemberIds: string[]
): Record<string, number> {
  const memberItemSubtotals: Record<string, number> = {};

  // Initialize all members with 0
  for (const mId of allMemberIds) {
    memberItemSubtotals[mId] = 0;
  }

  let totalItemsCalculated = 0;

  for (const item of lineItems) {
    const itemPrice = item.price;
    const splitType = item.splitType || 'equal';
    const assignments = item.assignments || [];
    const assignedUserIds =
      item.assignedUserIds && item.assignedUserIds.length > 0
        ? item.assignedUserIds
        : assignments.map((a) => a.userId);

    if (assignedUserIds.length === 0) {
      continue;
    }

    if (splitType === 'equal') {
      const perPerson = itemPrice / assignedUserIds.length;
      for (const uId of assignedUserIds) {
        memberItemSubtotals[uId] = (memberItemSubtotals[uId] || 0) + perPerson;
      }
      totalItemsCalculated += itemPrice;
    } else if (splitType === 'exact') {
      for (const a of assignments) {
        const val = a.value !== undefined ? a.value : itemPrice / assignments.length;
        memberItemSubtotals[a.userId] = (memberItemSubtotals[a.userId] || 0) + val;
        totalItemsCalculated += val;
      }
    } else if (splitType === 'shares') {
      const totalShares = assignments.reduce((sum, a) => sum + (a.value && a.value > 0 ? a.value : 1), 0);
      if (totalShares > 0) {
        for (const a of assignments) {
          const shareWeight = a.value && a.value > 0 ? a.value : 1;
          const shareAmount = (itemPrice * shareWeight) / totalShares;
          memberItemSubtotals[a.userId] = (memberItemSubtotals[a.userId] || 0) + shareAmount;
        }
        totalItemsCalculated += itemPrice;
      }
    } else if (splitType === 'percentage') {
      for (const a of assignments) {
        const pct = a.value !== undefined ? a.value : 100 / assignments.length;
        const pctAmount = (itemPrice * pct) / 100;
        memberItemSubtotals[a.userId] = (memberItemSubtotals[a.userId] || 0) + pctAmount;
      }
      totalItemsCalculated += itemPrice;
    } else if (splitType === 'quantity') {
      const totalUnits = assignments.reduce((sum, a) => sum + (a.value && a.value > 0 ? a.value : 1), 0);
      const unitPrice = totalUnits > 0 ? itemPrice / totalUnits : itemPrice / assignments.length;
      for (const a of assignments) {
        const qtyCount = a.value && a.value > 0 ? a.value : 1;
        const qtyAmount = unitPrice * qtyCount;
        memberItemSubtotals[a.userId] = (memberItemSubtotals[a.userId] || 0) + qtyAmount;
      }
      totalItemsCalculated += itemPrice;
    }
  }

  // Calculate proportional multiplier
  // Grand Total = Items Subtotal + Tax + ServiceCharge - Discount
  const finalGrandTotal = extras.totalAmount > 0 ? extras.totalAmount : totalItemsCalculated;
  const multiplier = totalItemsCalculated > 0 ? finalGrandTotal / totalItemsCalculated : 1;

  const finalSplits: Record<string, number> = {};
  let distributedSum = 0;
  const activeMembersWithDues = Object.keys(memberItemSubtotals).filter((mId) => memberItemSubtotals[mId] > 0);

  for (const mId of activeMembersWithDues) {
    const rawAllocated = memberItemSubtotals[mId] * multiplier;
    const rounded = Math.round(rawAllocated * 100) / 100;
    finalSplits[mId] = rounded;
    distributedSum += rounded;
  }

  // Assign any cent/paisa rounding difference to the largest stakeholder to guarantee exact sum
  if (activeMembersWithDues.length > 0 && Math.abs(finalGrandTotal - distributedSum) > 0.001) {
    const diff = Math.round((finalGrandTotal - distributedSum) * 100) / 100;
    // Find largest debtor
    let largestMember = activeMembersWithDues[0];
    for (const mId of activeMembersWithDues) {
      if (finalSplits[mId] > finalSplits[largestMember]) {
        largestMember = mId;
      }
    }
    finalSplits[largestMember] = Math.round((finalSplits[largestMember] + diff) * 100) / 100;
  }

  return finalSplits;
}

/**
 * Stitches and deduplicates multiple consecutive screenshots of long orders (e.g. Swiggy Instamart, BigBasket).
 * Eliminates overlapping items captured across scroll boundaries and preserves the final grand total.
 */
export function stitchMultiReceipts(rawTexts: string[]): ParsedReceiptData {
  if (!rawTexts || rawTexts.length === 0) {
    return {
      lineItems: [],
      subtotal: 0,
      taxAmount: 0,
      serviceCharge: 0,
      discountAmount: 0,
      totalAmount: 0,
      rawText: '',
    };
  }

  if (rawTexts.length === 1) {
    return parseReceiptText(rawTexts[0]);
  }

  const parsedList = rawTexts.map((txt) => parseReceiptText(txt));
  const mergedItems: Array<{ title: string; quantity: number; price: number }> = [];
  const seenKeySet = new Set<string>();

  for (const parsed of parsedList) {
    for (const item of parsed.lineItems) {
      // Key based on normalized title and price to detect overlaps
      const normTitle = item.title.toLowerCase().replace(/[^a-z0-9]/g, '');
      const key = `${normTitle}_${item.price.toFixed(0)}`;

      if (!seenKeySet.has(key)) {
        seenKeySet.add(key);
        mergedItems.push(item);
      }
    }
  }

  // Get taxes, fees and total from the last parsed slice (where footer summary lives)
  const lastSlice = parsedList[parsedList.length - 1];
  const firstSlice = parsedList[0];

  const subtotal = mergedItems.reduce((sum, it) => sum + it.price, 0);
  const taxAmount = lastSlice.taxAmount || firstSlice.taxAmount || 0;
  const serviceCharge = lastSlice.serviceCharge || firstSlice.serviceCharge || 0;
  const discountAmount = lastSlice.discountAmount || firstSlice.discountAmount || 0;
  const totalAmount =
    lastSlice.totalAmount > 0
      ? lastSlice.totalAmount
      : Math.max(0, subtotal + taxAmount + serviceCharge - discountAmount);

  return {
    merchantName: firstSlice.merchantName || lastSlice.merchantName || 'Multi-Screenshot Order',
    date: firstSlice.date || lastSlice.date,
    currency: 'INR',
    lineItems: mergedItems,
    subtotal: Math.round(subtotal * 100) / 100,
    taxAmount: Math.round(taxAmount * 100) / 100,
    serviceCharge: Math.round(serviceCharge * 100) / 100,
    discountAmount: Math.round(discountAmount * 100) / 100,
    totalAmount: Math.round(totalAmount * 100) / 100,
    rawText: rawTexts.join('\n--- SCREENSHOT BREAK ---\n'),
  };
}

/**
 * Built-in realistic sample receipts for quick testing and zero-friction on-device simulation.
 */
export const MOCK_RECEIPT_TEMPLATES: Record<string, { name: string; rawText: string; type?: 'pdf' | 'ocr' | 'multi' }> = {
  bigBasketPdf: {
    name: 'BigBasket Tax Invoice (PDF)',
    type: 'pdf',
    rawText: `INVOICE NO: BB-2026-892182
DATE: 29/08/2026
Billed to: Rahul Sharma
Sl. Description HSN Qty Unit Price Net Amount
1 Fresho Onion 1 kg 0703 1 38.00 38.00
2 Nandini Goodlife Milk 1 L 0401 2 54.00 108.00
3 Fortune Sunlite Refined Oil 1 L 1512 1 135.00 135.00
4 Aashirvaad Superior MP Atta 5 kg 1101 1 270.00 270.00
5 Farm Fresh Eggs Pack of 6 0407 1 58.00 58.00
6 Amul Salted Butter 100g 0405 1 56.00 56.00
7 Fresho Capsicum Green 500g 0709 1 45.00 45.00
Delivery Charges: 29.00
CGST (2.5%): 17.75
SGST (2.5%): 17.75
Total Savings: 69.00
Grand Total: 756.50`,
  },
  instamartMulti: {
    name: 'Swiggy Instamart (Multi-Screenshot)',
    type: 'multi',
    rawText: `Swiggy Instamart Order #1928371982
Date: 29 Aug 2026, 09:42 PM
1x Epigamia Greek Yogurt Blueberry 120g - ₹60.00
2x Coca-Cola Zero Sugar 300ml - ₹80.00
1x Lay's India's Magic Masala 50g - ₹20.00
1x Country Bean Hazelnut Instant Coffee 50g - ₹325.00
1x Britannia 100% Whole Wheat Bread - ₹45.00
1x Nestle Munch Pouch 200g - ₹95.00
Handling Fee: ₹5.00
Delivery Partner Fee: ₹25.00
Rain Surge Fee: ₹15.00
Coupon Discount: -₹50.00
Taxes & Charges (GST): ₹24.25
Total Paid: ₹644.25`,
  },
  blinkitShare: {
    name: 'Blinkit Grocery (Share/PDF)',
    type: 'pdf',
    rawText: `Blinkit Order #BLNK-882193
Delivered in 9 mins to Flat 302
- Amul Taaza Homogenised Toned Milk (500 ml) x 2 = ₹54.00
- Modern White Bread (400 g) x 1 = ₹45.00
- Amul Salted Butter (100 g) x 1 = ₹58.00
- Maggi 2-Minute Noodles (Pack of 4) x 1 = ₹56.00
Handling Charge: ₹4.00
GST (18% on platform): ₹0.72
Total Amount: ₹217.72`,
  },
  burgerJoint: {
    name: 'Biggies Burgers & Shakes',
    type: 'ocr',
    rawText: `Biggies Burgers & Shakes
Bill No: 4892  Date: 29/08/2026
1x Truffle Mushroom Burger 380.00
2x Loaded Cheese Nachos 420.00
1x Peri Peri Fries 170.00
3x Cold Brew Iced Coffee 360.00
Sub Total: 1330.00
CGST (2.5%): 33.25
SGST (2.5%): 33.25
Service Charge (5%): 66.50
Discount (Zomato Pro): 150.00
Grand Total: 1313.00
Thank you for visiting!`,
  },
  italianCafe: {
    name: 'Trattoria Bella Napoli',
    type: 'ocr',
    rawText: `Trattoria Bella Napoli
Table: 12  Order: 104
1 Wood Fired Margherita Pizza 450.00
1 Creamy Fettuccine Alfredo 380.00
2 Garlic Bread with Cheese 240.00
2 Sparkling Lime Mint Cooler 220.00
Subtotal: 1290.00
GST (5%): 64.50
Total: 1354.50`,
  },
  hostelDinner: {
    name: 'Late Night Biryani House',
    type: 'ocr',
    rawText: `Late Night Biryani House
Order No: 8821
2 Chicken Dum Biryani 560.00
1 Paneer Butter Masala 280.00
4 Butter Roti 120.00
1 Gulab Jamun (4 Pcs) 140.00
Items Total: 1100.00
GST (5%): 55.00
Packaging Charge: 40.00
Net Amount: 1195.00`,
  },
};

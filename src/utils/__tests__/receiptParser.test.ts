import {
  parseReceiptText,
  calculateItemizedSplits,
  stitchMultiReceipts,
  MOCK_RECEIPT_TEMPLATES,
} from '../receiptParser';
import { parseInvoicePdfText } from '../pdfInvoiceParser';
import { LineItem } from '@/types';

describe('receiptParser — On-Device OCR & Itemized Split Engine', () => {
  describe('parseReceiptText', () => {
    it('should parse burger joint receipt with dishes, quantities, taxes, discounts, and total', () => {
      const parsed = parseReceiptText(MOCK_RECEIPT_TEMPLATES.burgerJoint.rawText);

      expect(parsed.merchantName).toBe('Biggies Burgers & Shakes');
      expect(parsed.lineItems.length).toBe(4);
      expect(parsed.lineItems[0]).toEqual({
        title: 'Truffle Mushroom Burger',
        quantity: 1,
        price: 380.0,
      });
      expect(parsed.lineItems[1]).toEqual({
        title: 'Loaded Cheese Nachos',
        quantity: 2,
        price: 420.0,
      });
      expect(parsed.subtotal).toBe(1330.0);
      expect(parsed.taxAmount).toBe(66.5); // 33.25 + 33.25
      expect(parsed.serviceCharge).toBe(66.5);
      expect(parsed.discountAmount).toBe(150.0);
      expect(parsed.totalAmount).toBe(1313.0);
    });

    it('should parse Italian cafe receipt with GST accurately', () => {
      const parsed = parseReceiptText(MOCK_RECEIPT_TEMPLATES.italianCafe.rawText);

      expect(parsed.merchantName).toBe('Trattoria Bella Napoli');
      expect(parsed.lineItems.length).toBe(4);
      expect(parsed.subtotal).toBe(1290.0);
      expect(parsed.taxAmount).toBe(64.5);
      expect(parsed.totalAmount).toBe(1354.5);
    });

    it('should handle empty or invalid input gracefully', () => {
      const parsed = parseReceiptText('');
      expect(parsed.lineItems).toEqual([]);
      expect(parsed.totalAmount).toBe(0);
    });
  });

  describe('calculateItemizedSplits', () => {
    const members = ['user_rahul', 'user_alex', 'user_sam'];

    it('should compute exact proportional splits for equal sharing with GST and discount', () => {
      const items: LineItem[] = [
        {
          id: '1',
          title: 'Truffle Burger',
          price: 380,
          quantity: 1,
          splitType: 'equal',
          assignedUserIds: ['user_rahul'], // Only Rahul
        },
        {
          id: '2',
          title: 'Loaded Nachos',
          price: 420,
          quantity: 1,
          splitType: 'equal',
          assignedUserIds: ['user_rahul', 'user_alex', 'user_sam'], // Shared by all 3 (140 each)
        },
        {
          id: '3',
          title: 'Cold Brew Coffee',
          price: 200,
          quantity: 1,
          splitType: 'equal',
          assignedUserIds: ['user_alex'], // Only Alex
        },
      ];

      // Subtotal = 380 + 420 + 200 = 1000.
      // Total = 1100 (e.g. 10% tax/service charge)
      const splits = calculateItemizedSplits(
        items,
        {
          subtotal: 1000,
          taxAmount: 100,
          serviceCharge: 0,
          discountAmount: 0,
          totalAmount: 1100,
        },
        members
      );

      // Rahul item subtotal: 380 + 140 = 520 -> with 1.1x multiplier = 572
      // Alex item subtotal: 140 + 200 = 340 -> with 1.1x multiplier = 374
      // Sam item subtotal: 140 -> with 1.1x multiplier = 154
      expect(splits['user_rahul']).toBe(572);
      expect(splits['user_alex']).toBe(374);
      expect(splits['user_sam']).toBe(154);

      // Sum of splits must exactly equal totalAmount 1100
      const totalDistributed = Object.values(splits).reduce((a, b) => a + b, 0);
      expect(totalDistributed).toBe(1100);
    });

    it('should support per-item split modes: shares, exact, percentage, and quantity steppers', () => {
      const items: LineItem[] = [
        // 1. Shares (2:1 ratio) on a 600 rupee pizza
        {
          id: 'item_pizza',
          title: 'Large Pizza',
          price: 600,
          quantity: 1,
          splitType: 'shares',
          assignedUserIds: ['user_rahul', 'user_alex'],
          assignments: [
            { userId: 'user_rahul', splitType: 'shares', value: 2, calculatedAmount: 400 },
            { userId: 'user_alex', splitType: 'shares', value: 1, calculatedAmount: 200 },
          ],
        },
        // 2. Quantity stepper: 4 beers @ 800 (2 for Rahul, 2 for Sam)
        {
          id: 'item_beers',
          title: '4x Craft Beers',
          price: 800,
          quantity: 4,
          splitType: 'quantity',
          assignedUserIds: ['user_rahul', 'user_sam'],
          assignments: [
            { userId: 'user_rahul', splitType: 'quantity', value: 2, calculatedAmount: 400 },
            { userId: 'user_sam', splitType: 'quantity', value: 2, calculatedAmount: 400 },
          ],
        },
        // 3. Percentage: 70% Alex, 30% Sam on 200 rupee dessert
        {
          id: 'item_dessert',
          title: 'Tiramisu',
          price: 200,
          quantity: 1,
          splitType: 'percentage',
          assignedUserIds: ['user_alex', 'user_sam'],
          assignments: [
            { userId: 'user_alex', splitType: 'percentage', value: 70, calculatedAmount: 140 },
            { userId: 'user_sam', splitType: 'percentage', value: 30, calculatedAmount: 60 },
          ],
        },
      ];

      // Total = 600 + 800 + 200 = 1600
      const splits = calculateItemizedSplits(
        items,
        {
          subtotal: 1600,
          taxAmount: 0,
          serviceCharge: 0,
          discountAmount: 0,
          totalAmount: 1600,
        },
        members
      );

      // Rahul: 400 (pizza) + 400 (beers) = 800
      // Alex: 200 (pizza) + 140 (dessert) = 340
      // Sam: 400 (beers) + 60 (dessert) = 460
      expect(splits['user_rahul']).toBe(800);
      expect(splits['user_alex']).toBe(340);
      expect(splits['user_sam']).toBe(460);

      const totalDistributed = Object.values(splits).reduce((a, b) => a + b, 0);
      expect(totalDistributed).toBe(1600);
    });
  });

  describe('parseInvoicePdfText — Digital Tax Invoice Parsing', () => {
    it('should parse BigBasket tax invoice PDF with 7 items, CGST, SGST, delivery and savings', () => {
      const parsed = parseInvoicePdfText(MOCK_RECEIPT_TEMPLATES.bigBasketPdf.rawText);

      expect(parsed.merchantName).toBe('BigBasket Supermarket');
      expect(parsed.lineItems.length).toBe(7);
      expect(parsed.lineItems[0]).toEqual({
        title: 'Fresho Onion 1 kg',
        quantity: 1,
        price: 38.0,
      });
      expect(parsed.lineItems[1]).toEqual({
        title: 'Nandini Goodlife Milk 1 L',
        quantity: 2,
        price: 108.0,
      });
      expect(parsed.serviceCharge).toBe(29.0); // Delivery charge
      expect(parsed.taxAmount).toBe(35.5); // 17.75 + 17.75
      expect(parsed.discountAmount).toBe(69.0); // Total savings
      expect(parsed.totalAmount).toBe(756.5);
    });

    it('should parse Blinkit order summary with pack sizes and platform fees', () => {
      const parsed = parseInvoicePdfText(MOCK_RECEIPT_TEMPLATES.blinkitShare.rawText);

      expect(parsed.merchantName).toBe('Blinkit Grocery');
      expect(parsed.lineItems.length).toBe(4);
      expect(parsed.lineItems[0].title).toContain('Amul Taaza Homogenised Toned Milk');
      expect(parsed.serviceCharge).toBe(4.0); // Handling charge
      expect(parsed.taxAmount).toBe(0.72);
      expect(parsed.totalAmount).toBe(217.72);
    });
  });

  describe('stitchMultiReceipts — Multi-Screenshot Deduplication', () => {
    it('should deduplicate overlapping items across consecutive scrolling screenshots', () => {
      const screenshotSlice1 = `Swiggy Instamart
1x Epigamia Greek Yogurt 120g - ₹60.00
2x Coca-Cola Zero Sugar 300ml - ₹80.00
1x Lay's India's Magic Masala 50g - ₹20.00`;

      // Screenshot 2 overlaps on Coke and Lay's but adds Coffee and Bread + footer
      const screenshotSlice2 = `Swiggy Instamart
2x Coca-Cola Zero Sugar 300ml - ₹80.00
1x Lay's India's Magic Masala 50g - ₹20.00
1x Country Bean Hazelnut Coffee 50g - ₹325.00
1x Britannia Whole Wheat Bread - ₹45.00
Handling Fee: ₹5.00
Delivery Partner Fee: ₹25.00
Total Paid: ₹560.00`;

      const stitched = stitchMultiReceipts([screenshotSlice1, screenshotSlice2]);

      // Total unique items must be 5 (Yogurt, Coke, Lays, Coffee, Bread)
      expect(stitched.lineItems.length).toBe(5);
      expect(stitched.lineItems.map((i) => i.title)).toEqual([
        'Epigamia Greek Yogurt 120g',
        'Coca-Cola Zero Sugar 300ml',
        "Lay's India's Magic Masala 50g",
        'Country Bean Hazelnut Coffee 50g',
        'Britannia Whole Wheat Bread',
      ]);
      expect(stitched.serviceCharge).toBe(30.0); // 5 + 25
      expect(stitched.totalAmount).toBe(560.0);
    });
  });
});

import {
  parseReceiptText,
  calculateItemizedSplits,
  stitchMultiReceipts,
} from '../receiptParser';
import { parseInvoicePdfText } from '../pdfInvoiceParser';
import { LineItem } from '@/types';

const SAMPLE_BURGER_RECEIPT = `Biggies Burgers & Shakes
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
Thank you for visiting!`;

const SAMPLE_CAFE_RECEIPT = `Trattoria Bella Napoli
Table: 12  Order: 104
1 Wood Fired Margherita Pizza 450.00
1 Creamy Fettuccine Alfredo 380.00
2 Garlic Bread with Cheese 240.00
2 Sparkling Lime Mint Cooler 220.00
Subtotal: 1290.00
GST (5%): 64.50
Total: 1354.50`;

const SAMPLE_BIGBASKET_PDF = `INVOICE NO: BB-2026-892182
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
Grand Total: 756.50`;

const SAMPLE_BLINKIT_SHARE = `Blinkit Order #BLNK-882193
Delivered in 9 mins to Flat 302
- Amul Taaza Homogenised Toned Milk (500 ml) x 2 = ₹54.00
- Modern White Bread (400 g) x 1 = ₹45.00
- Amul Salted Butter (100 g) x 1 = ₹58.00
- Maggi 2-Minute Noodles (Pack of 4) x 1 = ₹56.00
Handling Charge: ₹4.00
GST (18% on platform): ₹0.72
Total Amount: ₹217.72`;

describe('receiptParser — On-Device OCR & Itemized Split Engine', () => {
  describe('parseReceiptText', () => {
    it('should parse burger joint receipt with dishes, quantities, taxes, discounts, and total', () => {
      const parsed = parseReceiptText(SAMPLE_BURGER_RECEIPT);

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
      const parsed = parseReceiptText(SAMPLE_CAFE_RECEIPT);

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
      const parsed = parseInvoicePdfText(SAMPLE_BIGBASKET_PDF);

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
      const parsed = parseInvoicePdfText(SAMPLE_BLINKIT_SHARE);

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

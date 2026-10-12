import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/models/receipt_data.dart';
import 'package:fairshare/data/services/gemini_vision_service.dart';

void main() {
  group('ParsedReceiptData', () {
    test('deserializes complete valid JSON payload', () {
      final json = {
        'merchantName': 'Starbucks Coffee',
        'date': '2026-10-12',
        'category': 'dining',
        'items': [
          {'name': 'Caramel Macchiato', 'quantity': 2, 'price': 580.0},
          {'name': 'Croissant', 'quantity': 1, 'price': 220.0},
        ],
        'subtotal': 800.0,
        'tax': 40.0,
        'discount': 20.0,
        'totalAmount': 820.0,
      };

      final parsed = ParsedReceiptData.fromJson(json);

      expect(parsed.merchantName, 'Starbucks Coffee');
      expect(parsed.date, '2026-10-12');
      expect(parsed.category, 'dining');
      expect(parsed.items.length, 2);
      expect(parsed.items[0].name, 'Caramel Macchiato');
      expect(parsed.items[0].quantity, 2);
      expect(parsed.items[0].price, 580.0);
      expect(parsed.subtotal, 800.0);
      expect(parsed.tax, 40.0);
      expect(parsed.discount, 20.0);
      expect(parsed.totalAmount, 820.0);
    });

    test('handles missing or null attributes with safe defaults', () {
      final json = <String, dynamic>{
        'merchantName': null,
        'items': null,
        'totalAmount': null,
      };

      final parsed = ParsedReceiptData.fromJson(json);

      expect(parsed.merchantName, 'Receipt');
      expect(parsed.category, 'dining');
      expect(parsed.items, isEmpty);
      expect(parsed.subtotal, 0.0);
      expect(parsed.totalAmount, 0.0);
    });

    test('handles string-encoded numeric values and snake_case keys', () {
      final json = {
        'merchant_name': 'Supermarket',
        'date': '2026-09-28',
        'category': 'groceries',
        'items': [
          {'name': 'Oats', 'quantity': '2', 'price': '199.50'},
        ],
        'subtotal': '399.00',
        'tax': '19.95',
        'discount': '0.00',
        'total_amount': '418.95',
      };

      final parsed = ParsedReceiptData.fromJson(json);

      expect(parsed.merchantName, 'Supermarket');
      expect(parsed.items.length, 1);
      expect(parsed.items[0].quantity, 2);
      expect(parsed.items[0].price, 199.50);
      expect(parsed.totalAmount, 418.95);
      expect(parsed.subtotal, 399.0);
    });
  });

  group('GeminiVisionService', () {
    test('returns null when API key is empty or null', () async {
      final service = GeminiVisionService(apiKey: '');
      final result = await service.parseReceiptBytes(Uint8List.fromList([1, 2, 3]));
      expect(result, isNull);
    });

    test('returns null when API key contains placeholder', () async {
      final service = GeminiVisionService(apiKey: 'placeholder_key');
      final result = await service.parseReceiptBytes(Uint8List.fromList([1, 2, 3]));
      expect(result, isNull);
    });
  });
}

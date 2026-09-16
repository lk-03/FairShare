import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/config/app_config.dart';
import '../../core/models/receipt_data.dart';

final geminiVisionServiceProvider = Provider<GeminiVisionService>((ref) {
  return GeminiVisionService();
});

class GeminiVisionService {
  final String? apiKey;

  GeminiVisionService({this.apiKey});

  /// Analyzes an image of a receipt/bill using Gemini Flash Vision and parses
  /// vendor, line items, taxes, and total into structured ParsedReceiptData.
  Future<ParsedReceiptData?> parseReceiptBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final key = apiKey ?? AppConfig.geminiApiKey;
    if (key == null || key.isEmpty || key.contains('placeholder')) {
      return null;
    }

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: key,
    );

    const promptText = '''
You are a high-accuracy Receipt & Invoice OCR Parser for the FairShare group expense splitter.
Analyze this receipt or invoice image carefully.
Extract:
1. "merchantName": The store, restaurant, or vendor name (e.g. "Blinkit", "Swiggy", "Subway", "Toit").
2. "date": Transaction date formatted as YYYY-MM-DD.
3. "category": One of ["groceries", "dining", "travel", "entertainment", "shopping", "utilities", "general"].
4. "items": Array of objects with "name" (clean product title), "quantity" (number, default 1), and "price" (total item cost).
5. "subtotal": Sum of items before tax/discounts.
6. "tax": GST, VAT, service tax, or tip total.
7. "discount": Total discount or coupon deductions (positive number).
8. "totalAmount": Grand total amount paid.

Return ONLY valid JSON matching this structure without markdown code fences or backticks:
{
  "merchantName": "Store Name",
  "date": "2026-09-14",
  "category": "dining",
  "items": [
    {"name": "Item 1", "quantity": 1, "price": 100}
  ],
  "subtotal": 100,
  "tax": 5,
  "discount": 0,
  "totalAmount": 105
}
''';

    try {
      final prompt = TextPart(promptText);
      final imagePart = DataPart(mimeType, imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      final text = response.text;
      if (text == null || text.trim().isEmpty) return null;

      String cleanJson = text.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return ParsedReceiptData.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/config/app_config.dart';
import '../../core/models/receipt_data.dart';

final geminiVisionServiceProvider = Provider<GeminiVisionService>((ref) {
  return GeminiVisionService();
});

class GeminiVisionService {
  final String? apiKey;

  // Cached model name across service calls in memory
  static String? _cachedModelName;

  // Static list of known resilient fallback models if discovery fails
  static const List<String> _fallbackModels = [
    'gemini-3.5-flash-lite',
    'gemini-3.5-flash',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  GeminiVisionService({this.apiKey});

  /// Dynamically queries Google's ModelService to discover all available models supporting
  /// generateContent, scored to prioritize lightweight and fast multimodal Flash models.
  Future<List<String>> discoverAvailableModels(String key) async {
    try {
      final client = HttpClient();
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$key',
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return _fallbackModels;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final models = data['models'] as List<dynamic>? ?? [];

      final candidates = <String>[];
      for (final m in models) {
        if (m is Map<String, dynamic>) {
          final methods = (m['supportedGenerationMethods'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final rawName = m['name'] as String? ?? '';
          final name = rawName.replaceFirst('models/', '');

          // Must support generateContent, exclude specialized TTS/robotics/preview-old models
          if (methods.contains('generateContent') &&
              name.contains('flash') &&
              !name.contains('tts') &&
              !name.contains('preview-10')) {
            candidates.add(name);
          }
        }
      }

      if (candidates.isEmpty) return _fallbackModels;

      // Score and rank models to prioritize flash-lite and flash models
      candidates.sort((a, b) {
        int score(String name) {
          if (name == 'gemini-3.5-flash-lite') return 1;
          if (name == 'gemini-3.5-flash') return 2;
          if (name == 'gemini-flash-lite-latest') return 3;
          if (name == 'gemini-flash-latest') return 4;
          if (name.contains('flash-lite')) return 5;
          if (name.contains('flash')) return 6;
          return 50;
        }
        return score(a).compareTo(score(b));
      });

      return candidates;
    } catch (e) {
      debugPrint('[GeminiVisionService] Model discovery error: $e');
      return _fallbackModels;
    }
  }

  /// Analyzes an image of a receipt/bill using Gemini Flash Vision and parses
  /// vendor, line items, taxes, and total into structured ParsedReceiptData.
  /// Automatically discovers and adapts to available Gemini models.
  Future<ParsedReceiptData?> parseReceiptBytes(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final key = apiKey ?? AppConfig.geminiApiKey;
    if (key == null || key.isEmpty || key.contains('placeholder')) {
      debugPrint('[GeminiVisionService] Gemini API key is missing or invalid.');
      return null;
    }

    // Determine candidate models
    List<String> candidates;
    if (_cachedModelName != null) {
      candidates = [
        _cachedModelName!,
        ..._fallbackModels.where((m) => m != _cachedModelName),
      ];
    } else {
      final discovered = await discoverAvailableModels(key);
      candidates = discovered.isNotEmpty ? discovered : _fallbackModels;
    }

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

    for (final modelName in candidates) {
      try {
        debugPrint('[GeminiVisionService] Attempting OCR with model: $modelName');
        final model = GenerativeModel(
          model: modelName,
          apiKey: key,
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.1,
          ),
        );

        final prompt = TextPart(promptText);
        final imagePart = DataPart(mimeType, imageBytes);

        final response = await model.generateContent([
          Content.multi([prompt, imagePart]),
        ]);

        final text = response.text;
        if (text == null || text.trim().isEmpty) continue;

        String cleanJson = text.trim();
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleanJson);
        if (jsonMatch != null) {
          cleanJson = jsonMatch.group(0)!;
        }

        final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
        final result = ParsedReceiptData.fromJson(decoded);

        // Cache the working model name for future requests
        _cachedModelName = modelName;
        debugPrint('[GeminiVisionService] Successfully parsed receipt with model: $modelName');
        return result;
      } catch (e) {
        debugPrint('[GeminiVisionService] Model $modelName failed: $e');
        // If this model failed, invalidate cache and try next candidate
        if (_cachedModelName == modelName) {
          _cachedModelName = null;
        }
      }
    }

    return null;
  }
}

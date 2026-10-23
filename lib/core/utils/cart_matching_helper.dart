import '../../core/models/need_item.dart';

/// Helper to accurately identify pending House Cart items matching an expense title,
/// notes, or receipt line items.
class CartMatchingHelper {
  // Common units, measurements, and noise tokens to strip
  static final RegExp _unitsAndQuantitiesRegex = RegExp(
    r'\b(\d+([.,]\d+)?\s*(kg|g|gm|gms|gram|grams|kilo|kilos|l|ltr|liter|liters|litre|litres|ml|lbs|lb|oz|pack|packs|packet|packets|pkt|pkts|box|boxes|bottle|bottles|can|cans|bunch|bunches|pcs|pc|piece|pieces|dozen|doz)?)\b',
    caseSensitive: false,
  );

  // Common stop words that don't represent unique item identities
  static const Set<String> _stopWords = {
    'a',
    'an',
    'the',
    'and',
    'or',
    'of',
    'for',
    'in',
    'on',
    'to',
    'with',
    'bought',
    'buy',
    'get',
    'got',
    'item',
    'items',
    'grocery',
    'groceries',
    'supermarket',
    'store',
    'shop',
  };

  /// Normalizes a string by stripping punctuation, extra spaces, quantities, and units.
  static String normalize(String text) {
    var cleaned = text.toLowerCase();
    cleaned = cleaned.replaceAll(_unitsAndQuantitiesRegex, ' ');
    // Remove non-alphanumeric characters except spaces
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Extracts significant search tokens from a string.
  static List<String> extractKeywords(String text) {
    final normalized = normalize(text);
    if (normalized.isEmpty) return [];

    return normalized
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.length >= 2 && !_stopWords.contains(w))
        .toList();
  }

  /// Builds a flexible regex pattern matching a keyword with word boundaries
  /// and English plural variations (e.g. "banana" matches "banana", "bananas"; "berry" matches "berries").
  static RegExp buildWordPattern(String keyword) {
    final escaped = RegExp.escape(keyword);
    String pattern;

    if (keyword.endsWith('y') && keyword.length > 2) {
      // e.g. berry -> (berry|berries)
      final base = RegExp.escape(keyword.substring(0, keyword.length - 1));
      pattern = r'\b(' + escaped + r'|' + base + r'ies)\b';
    } else if (keyword.endsWith('s') && keyword.length > 3) {
      // e.g. bananas -> banana(s)?
      final singular = RegExp.escape(keyword.substring(0, keyword.length - 1));
      pattern = r'\b(' + singular + r'(s|es)?|' + escaped + r')\b';
    } else {
      // e.g. banana -> banana(s|es)?
      pattern = r'\b' + escaped + r'(s|es)?\b';
    }

    return RegExp(pattern, caseSensitive: false);
  }

  /// Checks if a single pending cart item matches the expense texts.
  static bool matchesNeedItem({
    required NeedItem need,
    required String expenseTitle,
    List<String> itemNames = const [],
    String? notes,
  }) {
    if (need.isCompleted || need.title.trim().isEmpty) return false;

    // Build consolidated candidate text strings
    final candidateTexts = <String>[
      expenseTitle,
      if (notes != null && notes.isNotEmpty) notes,
      ...itemNames.where((n) => n.trim().isNotEmpty),
    ];

    // Normalized title of cart item
    final cartTitleNormalized = normalize(need.title);
    if (cartTitleNormalized.isEmpty) return false;

    // 1. Direct multi-word substring match with word boundary
    // e.g. cart item is "Brown bread", candidate has "bought brown bread"
    final fullCartPattern = RegExp(
      r'\b' + RegExp.escape(cartTitleNormalized) + r'(s|es)?\b',
      caseSensitive: false,
    );
    for (final text in candidateTexts) {
      final normalizedCandidate = normalize(text);
      if (fullCartPattern.hasMatch(normalizedCandidate)) {
        return true;
      }
    }

    // 2. Significant keyword matching
    final keywords = extractKeywords(need.title);
    if (keywords.isEmpty) return false;

    // For single keyword needs (e.g. "Bananas", "Milk"), match word boundary
    if (keywords.length == 1) {
      final pattern = buildWordPattern(keywords.first);
      for (final text in candidateTexts) {
        final normalizedCandidate = normalize(text);
        if (pattern.hasMatch(normalizedCandidate)) {
          return true;
        }
      }
      return false;
    }

    // For multi-word needs (e.g. "Oat Milk", "Greek Yogurt"):
    // Check if at least 70% of keywords appear in any single candidate text
    for (final text in candidateTexts) {
      final normalizedCandidate = normalize(text);
      int matchedCount = 0;
      for (final kw in keywords) {
        final pattern = buildWordPattern(kw);
        if (pattern.hasMatch(normalizedCandidate)) {
          matchedCount++;
        }
      }
      if (matchedCount / keywords.length >= 0.7) {
        return true;
      }
    }

    return false;
  }

  /// Finds all uncompleted cart items that match the given expense data.
  static List<NeedItem> findMatchingCartItems({
    required String expenseTitle,
    List<String> itemNames = const [],
    String? notes,
    required List<NeedItem> uncompletedCartItems,
  }) {
    if (uncompletedCartItems.isEmpty) return [];

    final matched = <NeedItem>[];
    for (final need in uncompletedCartItems) {
      if (matchesNeedItem(
        need: need,
        expenseTitle: expenseTitle,
        itemNames: itemNames,
        notes: notes,
      )) {
        matched.add(need);
      }
    }
    return matched;
  }
}

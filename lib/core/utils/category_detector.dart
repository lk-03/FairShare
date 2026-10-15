/// Keyword-based auto-categorization utility for expense titles.
class CategoryDetector {
  static const Map<String, Set<String>> _categoryKeywords = {
    'dining': {
      'swiggy', 'zomato', 'dinner', 'lunch', 'breakfast', 'brunch', 'food',
      'cafe', 'coffee', 'restaurant', 'starbucks', 'mcdonalds', 'kfc',
      'burger', 'pizza', 'biryani', 'snack', 'snacks', 'chai', 'tea',
      'drinks', 'beer', 'wine', 'pub', 'bar', 'dining', 'meal', 'meals',
      'bakery', 'dessert', 'icecream', 'sweets', 'cocktail', 'juice',
    },
    'house': {
      'rent', 'maid', 'grocery', 'groceries', 'dmart', 'instamart', 'blinkit',
      'zepto', 'bigbasket', 'milk', 'veggies', 'vegetables', 'fruits',
      'detergent', 'soap', 'cleaning', 'cook', 'repair', 'plumber',
      'electrician', 'maintenance', 'furniture', 'appliances',
    },
    'transport': {
      'uber', 'ola', 'rapido', 'cab', 'taxi', 'auto', 'metro', 'petrol',
      'diesel', 'fuel', 'cng', 'flight', 'airline', 'train', 'irctc',
      'bus', 'redbus', 'toll', 'fastag', 'parking', 'commute',
    },
    'utilities': {
      'electricity', 'power', 'bescom', 'water', 'gas', 'cylinder',
      'wifi', 'internet', 'broadband', 'airtel', 'jio', 'recharge',
      'dth', 'utility',
    },
    'event': {
      'movie', 'cinema', 'pvr', 'inox', 'ticket', 'tickets', 'concert',
      'party', 'clubbing', 'resort', 'staycation', 'trek', 'museum',
      'exhibition', 'celebration', 'ipl', 'match', 'netflix', 'spotify',
      'hotstar', 'show', 'game', 'entertainment',
    },
  };

  /// Analyzes an expense [title] and returns the detected category:
  /// - Returns the matching category if keywords match exactly 1 category.
  /// - Returns `'custom'` (Miscellaneous) if keywords trigger multiple conflicting categories.
  /// - Returns `null` if no matching keywords are found.
  static String? detectCategory(String title) {
    final clean = title.toLowerCase().trim();
    if (clean.isEmpty) return null;

    final words = clean
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toSet();

    final matchedCategories = <String>{};

    for (final entry in _categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;

      for (final keyword in keywords) {
        if (words.contains(keyword) || clean.contains(keyword)) {
          matchedCategories.add(category);
          break;
        }
      }
    }

    if (matchedCategories.isEmpty) {
      return null;
    }

    if (matchedCategories.length > 1) {
      // Multiple conflicting category triggers -> Miscellaneous ('custom')
      return 'custom';
    }

    return matchedCategories.first;
  }
}

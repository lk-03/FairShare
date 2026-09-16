class ParsedReceiptItem {
  final String name;
  final int quantity;
  final double price;

  const ParsedReceiptItem({
    required this.name,
    this.quantity = 1,
    required this.price,
  });

  factory ParsedReceiptItem.fromJson(Map<String, dynamic> json) {
    return ParsedReceiptItem(
      name: json['name'] as String? ?? 'Item',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  ParsedReceiptItem copyWith({
    String? name,
    int? quantity,
    double? price,
  }) {
    return ParsedReceiptItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
    );
  }
}

class ParsedReceiptData {
  final String merchantName;
  final String date;
  final String category;
  final List<ParsedReceiptItem> items;
  final double subtotal;
  final double tax;
  final double discount;
  final double totalAmount;
  final String source;

  const ParsedReceiptData({
    required this.merchantName,
    required this.date,
    this.category = 'dining',
    this.items = const [],
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.discount = 0.0,
    required this.totalAmount,
    this.source = 'gemini_vision',
  });

  factory ParsedReceiptData.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'];
    List<ParsedReceiptItem> parsedItems = [];
    if (rawItems != null && rawItems is List) {
      parsedItems = rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => ParsedReceiptItem.fromJson(i))
          .toList();
    }

    final total = (json['totalAmount'] as num?)?.toDouble() ??
        (json['total_amount'] as num?)?.toDouble() ??
        0.0;
    final sub = (json['subtotal'] as num?)?.toDouble() ?? total;

    return ParsedReceiptData(
      merchantName: json['merchantName'] as String? ??
          json['merchant_name'] as String? ??
          'Receipt',
      date: json['date'] as String? ?? DateTime.now().toIso8601String().substring(0, 10),
      category: json['category'] as String? ?? 'dining',
      items: parsedItems,
      subtotal: sub,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: total,
      source: json['source'] as String? ?? 'gemini_vision',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'merchantName': merchantName,
      'date': date,
      'category': category,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'totalAmount': totalAmount,
      'source': source,
    };
  }
}

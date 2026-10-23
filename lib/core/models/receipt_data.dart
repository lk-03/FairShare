double _toDouble(dynamic val, [double fallback = 0.0]) {
  if (val == null) return fallback;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString()) ?? fallback;
}

int _toInt(dynamic val, [int fallback = 1]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  return int.tryParse(val.toString()) ?? fallback;
}

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
      name: json['name']?.toString() ?? 'Item',
      quantity: _toInt(json['quantity'], 1),
      price: _toDouble(json['price'], 0.0),
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

    final total = _toDouble(json['totalAmount'] ?? json['total_amount'], 0.0);
    final sub = _toDouble(json['subtotal'], total);

    final merchant = json['merchantName']?.toString() ??
        json['merchant_name']?.toString() ??
        'Receipt';
    final date = json['date']?.toString() ??
        DateTime.now().toIso8601String().substring(0, 10);
    final category = json['category']?.toString() ?? 'dining';

    final tax = _toDouble(json['tax'], 0.0);
    final discount = _toDouble(json['discount'], 0.0);

    return ParsedReceiptData(
      merchantName: merchant.isNotEmpty ? merchant : 'Receipt',
      date: date.isNotEmpty ? date : DateTime.now().toIso8601String().substring(0, 10),
      category: category.isNotEmpty ? category : 'dining',
      items: parsedItems,
      subtotal: sub,
      tax: tax,
      discount: discount,
      totalAmount: total,
      source: json['source']?.toString() ?? 'gemini_vision',
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

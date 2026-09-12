import 'split.dart';

class Expense {
  final String id;
  final String cohortId;
  final String title;
  final String category;
  final String? customIcon;
  final double totalAmount;
  final String currency;
  final String paidByUserId;
  final SplitType splitType;
  final List<ExpenseSplit> splits;
  final String? receiptUrl;
  final bool ocrParsed;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? paidByName;

  const Expense({
    required this.id,
    required this.cohortId,
    required this.title,
    this.category = 'dining',
    this.customIcon,
    required this.totalAmount,
    this.currency = 'INR',
    required this.paidByUserId,
    this.splitType = SplitType.equal,
    this.splits = const [],
    this.receiptUrl,
    this.ocrParsed = false,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.paidByName,
  });

  /// Calculates personal share of this expense for a given user ID
  double userShare(String userId) {
    for (final s in splits) {
      if (s.userId == userId) return s.amount;
    }
    return 0.0;
  }

  /// Calculates net impact on the user (+ money they are owed, - money they owe)
  double userNetBalance(String userId) {
    final paid = paidByUserId == userId ? totalAmount : 0.0;
    final share = userShare(userId);
    return paid - share;
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    var rawSplits = json['splits'] ?? json['expense_splits'];
    List<ExpenseSplit> parsedSplits = [];
    if (rawSplits != null && rawSplits is List) {
      parsedSplits = rawSplits
          .whereType<Map<String, dynamic>>()
          .map((s) => ExpenseSplit.fromJson(s))
          .toList();
    }

    return Expense(
      id: json['id'] as String,
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'dining',
      customIcon: json['custom_icon'] as String? ?? json['customIcon'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ??
          (json['totalAmount'] as num?)?.toDouble() ??
          0.0,
      currency: json['currency'] as String? ?? 'INR',
      paidByUserId: json['paid_by_user_id'] as String? ??
          json['paidByUserId'] as String? ??
          '',
      splitType: SplitType.fromString(
        json['split_type'] as String? ?? json['splitType'] as String?,
      ),
      splits: parsedSplits,
      receiptUrl: json['receipt_url'] as String? ?? json['receiptUrl'] as String?,
      ocrParsed: json['ocr_parsed'] as bool? ?? json['ocrParsed'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : (json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
      paidByName: json['paid_by_name'] as String? ?? json['paidByName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cohort_id': cohortId,
      'title': title,
      'category': category,
      if (customIcon != null) 'custom_icon': customIcon,
      'total_amount': totalAmount,
      'currency': currency,
      'paid_by_user_id': paidByUserId,
      'split_type': splitType.toDbString(),
      'splits': splits.map((s) => s.toJson()).toList(),
      if (receiptUrl != null) 'receipt_url': receiptUrl,
      'ocr_parsed': ocrParsed,
      if (notes != null) 'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Expense copyWith({
    String? id,
    String? cohortId,
    String? title,
    String? category,
    String? customIcon,
    double? totalAmount,
    String? currency,
    String? paidByUserId,
    SplitType? splitType,
    List<ExpenseSplit>? splits,
    String? receiptUrl,
    bool? ocrParsed,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? paidByName,
  }) {
    return Expense(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      title: title ?? this.title,
      category: category ?? this.category,
      customIcon: customIcon ?? this.customIcon,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      paidByUserId: paidByUserId ?? this.paidByUserId,
      splitType: splitType ?? this.splitType,
      splits: splits ?? this.splits,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      ocrParsed: ocrParsed ?? this.ocrParsed,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidByName: paidByName ?? this.paidByName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum SplitType {
  equal,
  exact,
  percentage,
  shares,
  adjustment,
  itemized;

  static SplitType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'exact':
        return SplitType.exact;
      case 'percentage':
        return SplitType.percentage;
      case 'shares':
        return SplitType.shares;
      case 'adjustment':
        return SplitType.adjustment;
      case 'itemized':
        return SplitType.itemized;
      case 'equal':
      default:
        return SplitType.equal;
    }
  }

  String toDbString() {
    switch (this) {
      case SplitType.equal:
        return 'equal';
      case SplitType.exact:
        return 'exact';
      case SplitType.percentage:
        return 'percentage';
      case SplitType.shares:
        return 'shares';
      case SplitType.adjustment:
        return 'adjustment';
      case SplitType.itemized:
        return 'itemized';
    }
  }
}

class ExpenseSplit {
  final String userId;
  final double amount;
  final double? percentage;
  final double? shares;
  final double? adjustment;
  final List<String>? lineItemIds;

  const ExpenseSplit({
    required this.userId,
    required this.amount,
    this.percentage,
    this.shares,
    this.adjustment,
    this.lineItemIds,
  });

  factory ExpenseSplit.fromJson(Map<String, dynamic> json) {
    return ExpenseSplit(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      percentage: (json['percentage'] as num?)?.toDouble(),
      shares: (json['shares'] as num?)?.toDouble(),
      adjustment: (json['adjustment'] as num?)?.toDouble(),
      lineItemIds: json['line_item_ids'] != null
          ? List<String>.from(json['line_item_ids'] as List)
          : (json['lineItemIds'] != null
              ? List<String>.from(json['lineItemIds'] as List)
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': amount,
      if (percentage != null) 'percentage': percentage,
      if (shares != null) 'shares': shares,
      if (adjustment != null) 'adjustment': adjustment,
      if (lineItemIds != null) 'line_item_ids': lineItemIds,
    };
  }

  ExpenseSplit copyWith({
    String? userId,
    double? amount,
    double? percentage,
    double? shares,
    double? adjustment,
    List<String>? lineItemIds,
  }) {
    return ExpenseSplit(
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      percentage: percentage ?? this.percentage,
      shares: shares ?? this.shares,
      adjustment: adjustment ?? this.adjustment,
      lineItemIds: lineItemIds ?? this.lineItemIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseSplit &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          amount == other.amount &&
          adjustment == other.adjustment;

  @override
  int get hashCode => Object.hash(userId, amount, adjustment);
}

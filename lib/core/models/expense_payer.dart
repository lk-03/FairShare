class ExpensePayer {
  final String userId;
  final double amount;

  const ExpensePayer({
    required this.userId,
    required this.amount,
  });

  factory ExpensePayer.fromJson(Map<String, dynamic> json) {
    return ExpensePayer(
      userId: json['user_id'] as String? ?? json['userId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'amount': amount,
    };
  }

  ExpensePayer copyWith({
    String? userId,
    double? amount,
  }) {
    return ExpensePayer(
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpensePayer &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          (amount - other.amount).abs() < 0.001;

  @override
  int get hashCode => userId.hashCode ^ amount.hashCode;
}

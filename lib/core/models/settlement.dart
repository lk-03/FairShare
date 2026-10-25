import 'profile.dart';

class Settlement {
  final String id;
  final String cohortId;
  final String payerId;
  final String payeeId;
  final double amount;
  final String currency;
  final String status; // 'pending' | 'completed'
  final DateTime? paidAt;
  final String? upiRef;
  final UserProfile? payerProfile;
  final UserProfile? payeeProfile;

  const Settlement({
    required this.id,
    required this.cohortId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    this.currency = 'INR',
    this.status = 'completed',
    this.paidAt,
    this.upiRef,
    this.payerProfile,
    this.payeeProfile,
  });

  bool get isCompleted => status == 'completed';

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as String,
      cohortId: json['cohort_id'] as String? ?? json['cohortId'] as String? ?? '',
      payerId: json['payer_id'] as String? ?? json['payerId'] as String? ?? '',
      payeeId: json['payee_id'] as String? ?? json['payeeId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String? ?? 'completed',
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : (json['paidAt'] != null
              ? DateTime.tryParse(json['paidAt'].toString())
              : null),
      upiRef: json['upi_ref'] as String? ?? json['upiRef'] as String?,
      payerProfile: json['payer_profile'] != null && json['payer_profile'] is Map<String, dynamic>
          ? UserProfile.fromJson(json['payer_profile'] as Map<String, dynamic>)
          : null,
      payeeProfile: json['payee_profile'] != null && json['payee_profile'] is Map<String, dynamic>
          ? UserProfile.fromJson(json['payee_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cohort_id': cohortId,
      'payer_id': payerId,
      'payee_id': payeeId,
      'amount': amount,
      'currency': currency,
      'status': status,
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
      if (upiRef != null) 'upi_ref': upiRef,
    };
  }

  Settlement copyWith({
    String? id,
    String? cohortId,
    String? payerId,
    String? payeeId,
    double? amount,
    String? currency,
    String? status,
    DateTime? paidAt,
    String? upiRef,
    UserProfile? payerProfile,
    UserProfile? payeeProfile,
  }) {
    return Settlement(
      id: id ?? this.id,
      cohortId: cohortId ?? this.cohortId,
      payerId: payerId ?? this.payerId,
      payeeId: payeeId ?? this.payeeId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paidAt: paidAt ?? this.paidAt,
      upiRef: upiRef ?? this.upiRef,
      payerProfile: payerProfile ?? this.payerProfile,
      payeeProfile: payeeProfile ?? this.payeeProfile,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settlement && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

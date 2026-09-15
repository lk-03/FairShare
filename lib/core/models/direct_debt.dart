import 'profile.dart';

class DirectDebt {
  final String fromUserId;
  final UserProfile? fromProfile;
  final String toUserId;
  final UserProfile? toProfile;
  final double amount;
  final String currency;

  const DirectDebt({
    required this.fromUserId,
    this.fromProfile,
    required this.toUserId,
    this.toProfile,
    required this.amount,
    this.currency = 'INR',
  });

  String get fromName => fromProfile?.displayName ?? fromUserId;
  String get toName => toProfile?.displayName ?? toUserId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectDebt &&
          runtimeType == other.runtimeType &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          (amount - other.amount).abs() < 0.01;

  @override
  int get hashCode => Object.hash(fromUserId, toUserId, amount);

  @override
  String toString() =>
      'DirectDebt($fromName owes $toName: $currency $amount)';
}

class DebtSimplificationResult {
  final String cohortId;
  final Map<String, double> netBalances;
  final List<DirectDebt> simplifiedDebts;

  const DebtSimplificationResult({
    required this.cohortId,
    required this.netBalances,
    required this.simplifiedDebts,
  });
}

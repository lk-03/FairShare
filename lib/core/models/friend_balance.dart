import 'friend.dart';

class FriendBalance {
  final Friend friend;

  /// Net balance from current user's perspective:
  /// > 0: Friend owes current user
  /// < 0: Current user owes friend
  /// == 0: Settled up
  final double netAmount;
  final double totalSharedAmount;
  final int expenseCount;
  final DateTime? lastActivityAt;

  const FriendBalance({
    required this.friend,
    required this.netAmount,
    this.totalSharedAmount = 0.0,
    this.expenseCount = 0,
    this.lastActivityAt,
  });

  bool get isSettled => netAmount.abs() < 0.01;
  bool get friendOwesUser => netAmount > 0.01;
  bool get userOwesFriend => netAmount < -0.01;
  bool get owesYou => friendOwesUser;
  bool get youOwe => userOwesFriend;
  double get totalVolume => totalSharedAmount;

  double get absoluteAmount => netAmount.abs();
}

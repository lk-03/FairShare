import '../../../../core/models/group_member.dart';
import '../../../../core/models/receipt_data.dart';
import '../../../../core/models/split.dart';

enum TaxDistributionMode {
  proportional,
  equal,
}

class ReceiptSplitCalculator {
  const ReceiptSplitCalculator();

  /// Calculates per-member exact splits from parsed receipt items and user assignments.
  ///
  /// - [parsedData]: Parsed receipt with vendor, items, and total amount.
  /// - [members]: Group members participating in the group/expense.
  /// - [itemAssignments]: Map of item index to the set of member userIds who consumed the item.
  ///   If an item has an empty or null set, it is assumed to be shared equally by ALL members.
  /// - [taxMode]: Whether taxes, discounts, and fees are distributed proportionally to
  ///   each member's consumed items subtotal (default) or split equally among members.
  static List<ExpenseSplit> calculateSplits({
    required ParsedReceiptData parsedData,
    required List<GroupMember> members,
    required Map<int, Set<String>> itemAssignments,
    TaxDistributionMode taxMode = TaxDistributionMode.proportional,
  }) {
    if (members.isEmpty) return const [];

    final total = parsedData.totalAmount;
    if (total <= 0) {
      return members
          .map((m) => ExpenseSplit(userId: m.userId, amount: 0.0))
          .toList();
    }

    // If there are no line items, split the total equally among members
    if (parsedData.items.isEmpty) {
      return _calculateEqualSplits(total, members);
    }

    final allMemberIds = members.map((m) => m.userId).toSet();
    final Map<String, double> memberSubtotals = {
      for (final m in members) m.userId: 0.0,
    };

    for (var i = 0; i < parsedData.items.length; i++) {
      final item = parsedData.items[i];
      if (item.price <= 0) continue;

      final assigned = itemAssignments[i];
      final targetUserIds = (assigned != null && assigned.isNotEmpty)
          ? assigned.where(allMemberIds.contains).toSet()
          : allMemberIds;

      final effectiveTargets = targetUserIds.isEmpty ? allMemberIds : targetUserIds;
      final perMemberShare = item.price / effectiveTargets.length;

      for (final uid in effectiveTargets) {
        memberSubtotals[uid] = (memberSubtotals[uid] ?? 0.0) + perMemberShare;
      }
    }

    final totalAssignedItems = memberSubtotals.values.fold(0.0, (a, b) => a + b);
    final netDiff = total - totalAssignedItems;

    final Map<String, double> rawTotals = {};

    for (final m in members) {
      final uid = m.userId;
      final subtotal = memberSubtotals[uid] ?? 0.0;
      double taxShare = 0.0;

      if (netDiff.abs() > 0.0001) {
        if (taxMode == TaxDistributionMode.proportional && totalAssignedItems > 0) {
          taxShare = (subtotal / totalAssignedItems) * netDiff;
        } else {
          taxShare = netDiff / members.length;
        }
      }

      rawTotals[uid] = (subtotal + taxShare).clamp(0.0, double.infinity);
    }

    // Reconcile penny-rounding to ensure the sum matches total down to the exact cent
    return _reconcileSplits(rawTotals, total, members);
  }

  static List<ExpenseSplit> _calculateEqualSplits(
    double total,
    List<GroupMember> members,
  ) {
    final count = members.length;
    final base = (total / count * 100).floor() / 100.0;
    final remainder = double.parse((total - (base * count)).toStringAsFixed(2));

    return members.asMap().entries.map((entry) {
      final idx = entry.key;
      final m = entry.value;
      final amt = idx == 0 ? double.parse((base + remainder).toStringAsFixed(2)) : base;
      return ExpenseSplit(userId: m.userId, amount: amt);
    }).toList();
  }

  static List<ExpenseSplit> _reconcileSplits(
    Map<String, double> rawTotals,
    double targetTotal,
    List<GroupMember> members,
  ) {
    final Map<String, double> rounded = {};
    for (final m in members) {
      final val = rawTotals[m.userId] ?? 0.0;
      rounded[m.userId] = double.parse(val.toStringAsFixed(2));
    }

    final currentSum = rounded.values.fold(0.0, (a, b) => a + b);
    final diff = double.parse((targetTotal - currentSum).toStringAsFixed(2));

    if (diff.abs() > 0.001 && members.isNotEmpty) {
      // Find the member with the highest amount to adjust the rounding difference
      String maxUserId = members.first.userId;
      double maxAmount = rounded[maxUserId] ?? 0.0;

      for (final m in members) {
        final amt = rounded[m.userId] ?? 0.0;
        if (amt > maxAmount) {
          maxAmount = amt;
          maxUserId = m.userId;
        }
      }

      rounded[maxUserId] = double.parse(((rounded[maxUserId] ?? 0.0) + diff).toStringAsFixed(2));
    }

    return members.map((m) {
      return ExpenseSplit(
        userId: m.userId,
        amount: rounded[m.userId] ?? 0.0,
      );
    }).toList();
  }
}

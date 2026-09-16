import '../models/direct_debt.dart';
import '../models/expense.dart';
import '../models/group_member.dart';
import '../models/split.dart';

class _DebtorCreditorNode {
  final String userId;
  double amount;

  _DebtorCreditorNode({
    required this.userId,
    required this.amount,
  });
}

/// DebtSimplifier implements a Greedy Min-Flow Graph algorithm to resolve
/// cyclic multi-person IOUs and reduce N-person group debts down to the
/// mathematical minimum number of direct transactions.
class DebtSimplifier {
  /// Calculates net balances per user and generates the simplified debt transactions.
  static DebtSimplificationResult calculateSimplifiedDebts({
    required String cohortId,
    required List<GroupMember> members,
    required List<Expense> expenses,
  }) {
    final Map<String, double> netBalances = {};

    // 1. Initialize all members with 0.0 balance
    for (final m in members) {
      netBalances[m.userId] = 0.0;
    }

    // 2. Calculate net balances for each expense in this cohort
    for (final expense in expenses) {
      if (expense.cohortId != cohortId) continue;

      final paidBy = expense.paidByUserId;
      final totalAmount = expense.totalAmount;

      // Credit the payer(s)
      if (expense.payers.isNotEmpty) {
        for (final payer in expense.payers) {
          netBalances[payer.userId] =
              (netBalances[payer.userId] ?? 0.0) + payer.amount;
        }
      } else {
        netBalances[paidBy] = (netBalances[paidBy] ?? 0.0) + totalAmount;
      }

      // Debit participants according to split amounts
      final splits = expense.splits.isNotEmpty
          ? expense.splits
          : [ExpenseSplit(userId: paidBy, amount: totalAmount)];

      for (final split in splits) {
        netBalances[split.userId] =
            (netBalances[split.userId] ?? 0.0) - split.amount;
      }
    }

    // 3. Separate debtors (< -0.01) and creditors (> 0.01)
    final List<_DebtorCreditorNode> debtors = [];
    final List<_DebtorCreditorNode> creditors = [];

    final Map<String, double> roundedNetBalances = {};
    for (final entry in netBalances.entries) {
      // Round to 2 decimal places to avoid floating point precision artifacts
      final rounded = (entry.value * 100).round() / 100.0;
      roundedNetBalances[entry.key] = rounded;

      if (rounded < -0.01) {
        debtors.add(_DebtorCreditorNode(
          userId: entry.key,
          amount: rounded.abs(),
        ));
      } else if (rounded > 0.01) {
        creditors.add(_DebtorCreditorNode(
          userId: entry.key,
          amount: rounded,
        ));
      }
    }

    // 4. Sort debtors and creditors descending by amount
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    // 5. Greedy matching: match largest debtor with largest creditor
    final List<DirectDebt> simplifiedDebts = [];
    int i = 0; // debtor pointer
    int j = 0; // creditor pointer

    final currency = expenses.isNotEmpty ? expenses.first.currency : 'INR';

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final settledAmount = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      if (settledAmount > 0.01) {
        GroupMember? debtorMember;
        GroupMember? creditorMember;

        for (final m in members) {
          if (m.userId == debtor.userId) debtorMember = m;
          if (m.userId == creditor.userId) creditorMember = m;
        }

        simplifiedDebts.add(DirectDebt(
          fromUserId: debtor.userId,
          fromProfile: debtorMember?.profile,
          toUserId: creditor.userId,
          toProfile: creditorMember?.profile,
          amount: (settledAmount * 100).round() / 100.0,
          currency: currency,
        ));
      }

      debtor.amount -= settledAmount;
      creditor.amount -= settledAmount;

      if (debtor.amount < 0.01) i++;
      if (creditor.amount < 0.01) j++;
    }

    return DebtSimplificationResult(
      cohortId: cohortId,
      netBalances: roundedNetBalances,
      simplifiedDebts: simplifiedDebts,
    );
  }
}

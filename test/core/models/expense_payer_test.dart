import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/algorithms/debt_simplifier.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/expense_payer.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/split.dart';

void main() {
  group('ExpensePayer Model', () {
    test('serializes to and from JSON correctly', () {
      final payer = ExpensePayer(userId: 'usr_1', amount: 450.50);
      final json = payer.toJson();

      expect(json['user_id'], 'usr_1');
      expect(json['amount'], 450.50);

      final fromJson = ExpensePayer.fromJson(json);
      expect(fromJson.userId, 'usr_1');
      expect(fromJson.amount, 450.50);
    });

    test('handles camelCase and snake_case json decoding', () {
      final jsonCamel = {'userId': 'usr_2', 'amount': 120};
      final payer = ExpensePayer.fromJson(jsonCamel);
      expect(payer.userId, 'usr_2');
      expect(payer.amount, 120.0);
    });
  });

  group('Expense Multi-Payer Helpers', () {
    test('userPaid returns individual contribution when payers list is populated', () {
      final expense = Expense(
        id: 'exp_1',
        cohortId: 'grp_1',
        title: 'Team Dinner',
        totalAmount: 1000.0,
        paidByUserId: 'usr_1',
        payers: [
          ExpensePayer(userId: 'usr_1', amount: 600.0),
          ExpensePayer(userId: 'usr_2', amount: 400.0),
        ],
        splits: [
          ExpenseSplit(userId: 'usr_1', amount: 500.0),
          ExpenseSplit(userId: 'usr_2', amount: 500.0),
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(expense.userPaid('usr_1'), 600.0);
      expect(expense.userPaid('usr_2'), 400.0);
      expect(expense.userPaid('usr_3'), 0.0);
      expect(expense.userNetBalance('usr_1'), 100.0); // Paid 600, share 500 => +100
      expect(expense.userNetBalance('usr_2'), -100.0); // Paid 400, share 500 => -100
    });

    test('userPaid falls back to paidByUserId when payers list is empty', () {
      final expense = Expense(
        id: 'exp_2',
        cohortId: 'grp_1',
        title: 'Groceries',
        totalAmount: 300.0,
        paidByUserId: 'usr_1',
        payers: const [],
        splits: [
          ExpenseSplit(userId: 'usr_1', amount: 150.0),
          ExpenseSplit(userId: 'usr_2', amount: 150.0),
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      expect(expense.userPaid('usr_1'), 300.0);
      expect(expense.userPaid('usr_2'), 0.0);
      expect(expense.userNetBalance('usr_1'), 150.0);
      expect(expense.userNetBalance('usr_2'), -150.0);
    });
  });

  group('DebtSimplifier with Multi-Payer Expenses', () {
    test('calculates correct simplified debts when multiple people pay for one expense', () {
      // Total 1200 split equally among A, B, C (400 each)
      // Paid by: A pays 700, B pays 500, C pays 0
      // Net balances:
      // A: +700 - 400 = +300
      // B: +500 - 400 = +100
      // C: 0 - 400 = -400
      // Simplified debts: C owes A 300, C owes B 100
      final expense = Expense(
        id: 'exp_multi',
        cohortId: 'cohort_1',
        title: 'Weekend Airbnb',
        totalAmount: 1200.0,
        paidByUserId: 'usr_a',
        payers: [
          ExpensePayer(userId: 'usr_a', amount: 700.0),
          ExpensePayer(userId: 'usr_b', amount: 500.0),
        ],
        splits: [
          ExpenseSplit(userId: 'usr_a', amount: 400.0),
          ExpenseSplit(userId: 'usr_b', amount: 400.0),
          ExpenseSplit(userId: 'usr_c', amount: 400.0),
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final memberA = GroupMember(
        id: 'gm_a',
        cohortId: 'cohort_1',
        userId: 'usr_a',
        joinedAt: DateTime(2026, 1, 1),
      );
      final memberB = GroupMember(
        id: 'gm_b',
        cohortId: 'cohort_1',
        userId: 'usr_b',
        joinedAt: DateTime(2026, 1, 1),
      );
      final memberC = GroupMember(
        id: 'gm_c',
        cohortId: 'cohort_1',
        userId: 'usr_c',
        joinedAt: DateTime(2026, 1, 1),
      );

      final result = DebtSimplifier.calculateSimplifiedDebts(
        cohortId: 'cohort_1',
        members: [memberA, memberB, memberC],
        expenses: [expense],
      );

      final debts = result.simplifiedDebts;
      expect(debts.length, 2);

      final debtToA = debts.firstWhere((d) => d.toUserId == 'usr_a');
      expect(debtToA.fromUserId, 'usr_c');
      expect(debtToA.amount, 300.0);

      final debtToB = debts.firstWhere((d) => d.toUserId == 'usr_b');
      expect(debtToB.fromUserId, 'usr_c');
      expect(debtToB.amount, 100.0);
    });
  });
}

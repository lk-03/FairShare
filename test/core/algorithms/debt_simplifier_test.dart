import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/algorithms/debt_simplifier.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/split.dart';

void main() {
  group('DebtSimplifier Algorithm', () {
    final now = DateTime.now();
    final members = [
      GroupMember(
        id: 'm1',
        cohortId: 'c1',
        userId: 'user_A',
        role: 'admin',
        joinedAt: now,
        profile: UserProfile(
          id: 'user_A',
          fullName: 'Alice',
          createdAt: now,
        ),
      ),
      GroupMember(
        id: 'm2',
        cohortId: 'c1',
        userId: 'user_B',
        role: 'member',
        joinedAt: now,
        profile: UserProfile(
          id: 'user_B',
          fullName: 'Bob',
          createdAt: now,
        ),
      ),
      GroupMember(
        id: 'm3',
        cohortId: 'c1',
        userId: 'user_C',
        role: 'member',
        joinedAt: now,
        profile: UserProfile(
          id: 'user_C',
          fullName: 'Charlie',
          createdAt: now,
        ),
      ),
    ];

    test('should simplify simple pairwise debt', () {
      final expenses = [
        Expense(
          id: 'exp1',
          cohortId: 'c1',
          title: 'Dinner',
          category: 'Food',
          totalAmount: 300.0,
          currency: 'INR',
          paidByUserId: 'user_A',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(userId: 'user_A', amount: 100.0),
            ExpenseSplit(userId: 'user_B', amount: 100.0),
            ExpenseSplit(userId: 'user_C', amount: 100.0),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = DebtSimplifier.calculateSimplifiedDebts(
        cohortId: 'c1',
        members: members,
        expenses: expenses,
      );

      expect(result.netBalances['user_A'], 200.0);
      expect(result.netBalances['user_B'], -100.0);
      expect(result.netBalances['user_C'], -100.0);

      expect(result.simplifiedDebts.length, 2);

      // Verify B owes A 100, and C owes A 100
      final bToA = result.simplifiedDebts.firstWhere(
        (d) => d.fromUserId == 'user_B' && d.toUserId == 'user_A',
      );
      expect(bToA.amount, 100.0);

      final cToA = result.simplifiedDebts.firstWhere(
        (d) => d.fromUserId == 'user_C' && d.toUserId == 'user_A',
      );
      expect(cToA.amount, 100.0);
    });

    test('should resolve circular debt (A paid B, B paid C, C paid A) to 0 transactions', () {
      final expenses = [
        // A pays 30 for A & B (15 each) -> B owes A 15
        Expense(
          id: 'exp1',
          cohortId: 'c1',
          title: 'Lunch',
          category: 'Food',
          totalAmount: 30.0,
          currency: 'INR',
          paidByUserId: 'user_A',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(userId: 'user_A', amount: 15.0),
            ExpenseSplit(userId: 'user_B', amount: 15.0),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        // B pays 30 for B & C (15 each) -> C owes B 15
        Expense(
          id: 'exp2',
          cohortId: 'c1',
          title: 'Movie',
          category: 'Entertainment',
          totalAmount: 30.0,
          currency: 'INR',
          paidByUserId: 'user_B',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(userId: 'user_B', amount: 15.0),
            ExpenseSplit(userId: 'user_C', amount: 15.0),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        // C pays 30 for C & A (15 each) -> A owes C 15
        Expense(
          id: 'exp3',
          cohortId: 'c1',
          title: 'Cab',
          category: 'Travel',
          totalAmount: 30.0,
          currency: 'INR',
          paidByUserId: 'user_C',
          splitType: SplitType.equal,
          splits: const [
            ExpenseSplit(userId: 'user_C', amount: 15.0),
            ExpenseSplit(userId: 'user_A', amount: 15.0),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = DebtSimplifier.calculateSimplifiedDebts(
        cohortId: 'c1',
        members: members,
        expenses: expenses,
      );

      // Everyone spent 30 and received 30 -> all net balances are 0.0
      expect(result.netBalances['user_A'], 0.0);
      expect(result.netBalances['user_B'], 0.0);
      expect(result.netBalances['user_C'], 0.0);

      // Zero transactions needed to settle!
      expect(result.simplifiedDebts.isEmpty, true);
    });

    test('should handle asymmetric 4-party debt with optimal transaction count', () {
      final members4 = [
        ...members,
        GroupMember(
          id: 'm4',
          cohortId: 'c1',
          userId: 'user_D',
          role: 'member',
          joinedAt: now,
          profile: UserProfile(
            id: 'user_D',
            fullName: 'David',
            createdAt: now,
          ),
        ),
      ];

      // Alice pays 400 equally for all 4 (100 each)
      // Bob pays 200 equally for Bob & David (100 each)
      final expenses = [
        Expense(
          id: 'exp1',
          cohortId: 'c1',
          title: 'Villa',
          category: 'House',
          totalAmount: 400.0,
          paidByUserId: 'user_A',
          splits: const [
            ExpenseSplit(userId: 'user_A', amount: 100.0),
            ExpenseSplit(userId: 'user_B', amount: 100.0),
            ExpenseSplit(userId: 'user_C', amount: 100.0),
            ExpenseSplit(userId: 'user_D', amount: 100.0),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        Expense(
          id: 'exp2',
          cohortId: 'c1',
          title: 'Groceries',
          category: 'Food',
          totalAmount: 200.0,
          paidByUserId: 'user_B',
          splits: const [
            ExpenseSplit(userId: 'user_B', amount: 100.0),
            ExpenseSplit(userId: 'user_D', amount: 100.0),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final result = DebtSimplifier.calculateSimplifiedDebts(
        cohortId: 'c1',
        members: members4,
        expenses: expenses,
      );

      // Alice: +300
      // Bob: +200 - 100 - 100 = 0
      // Charlie: -100
      // David: -100 - 100 = -200
      expect(result.netBalances['user_A'], 300.0);
      expect(result.netBalances['user_B'], 0.0);
      expect(result.netBalances['user_C'], -100.0);
      expect(result.netBalances['user_D'], -200.0);

      // David pays Alice 200, Charlie pays Alice 100 => exactly 2 direct transactions!
      expect(result.simplifiedDebts.length, 2);
      final totalSettled = result.simplifiedDebts.fold<double>(
        0.0,
        (sum, d) => sum + d.amount,
      );
      expect(totalSettled, 300.0);
    });
  });
}

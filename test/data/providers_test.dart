import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/data/providers/needs_provider.dart';

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Riverpod Providers Integration', () {
    test('currentUserProvider initial state and profile mutations', () async {
      expect(container.read(currentUserProvider), isNull);

      final user = UserProfile(
        id: 'u_user1',
        fullName: 'John Doe',
        email: 'john@example.com',
        createdAt: DateTime(2026, 1, 1),
      );

      await container.read(currentUserProvider.notifier).setUser(user);
      expect(container.read(currentUserProvider)?.fullName, equals('John Doe'));

      await container.read(currentUserProvider.notifier).updateProfile(
            nickname: 'Johnny',
            vpaId: 'john@upi',
          );

      final updated = container.read(currentUserProvider);
      expect(updated?.displayName, equals('Johnny'));
      expect(updated?.vpaId, equals('john@upi'));

      await container.read(currentUserProvider.notifier).signOut();
      expect(container.read(currentUserProvider), isNull);
    });

    test('groupsProvider and activeGroupProvider lifecycle', () async {
      final user = UserProfile(
        id: 'u_lead',
        fullName: 'Leader',
        email: 'lead@fairshare.app',
        createdAt: DateTime(2026, 1, 1),
      );
      await container.read(currentUserProvider.notifier).setUser(user);

      final newGroup = Group(
        id: 'group_test_1',
        name: 'Apartment 3B',
        category: 'house',
        createdBy: user.id,
        inviteCode: 'APT3B1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final created =
          await container.read(groupsProvider.notifier).createGroup(newGroup);
      expect(created.name, equals('Apartment 3B'));

      final groups = container.read(groupsProvider).value ?? [];
      expect(groups.length, equals(1));

      // Active group tracking
      await container
          .read(activeGroupIdProvider.notifier)
          .setActiveGroupId('group_test_1');
      expect(container.read(activeGroupProvider)?.name, equals('Apartment 3B'));

      // Update group
      await container
          .read(groupsProvider.notifier)
          .updateGroup('group_test_1', {'name': 'Apartment 3B Penthouse'});

      expect(
        container
            .read(groupsProvider)
            .value!
            .first
            .name,
        equals('Apartment 3B Penthouse'),
      );
    });

    test('groupExpensesProvider, groupDebtsProvider, and net balance calculation',
        () async {
      final user1 = UserProfile(
        id: 'u_1',
        fullName: 'Alice',
        createdAt: DateTime(2026, 1, 1),
      );
      final user2 = UserProfile(
        id: 'u_2',
        fullName: 'Bob',
        createdAt: DateTime(2026, 1, 1),
      );
      await container.read(currentUserProvider.notifier).setUser(user1);

      // Create group with Alice and Bob
      final group = Group(
        id: 'grp_split',
        name: 'Road Trip',
        createdBy: user1.id,
        inviteCode: 'ROAD26',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        members: [
          GroupMember(
            id: 'm_1',
            cohortId: 'grp_split',
            userId: user1.id,
            role: 'admin',
            joinedAt: DateTime(2026, 1, 1),
            profile: user1,
          ),
          GroupMember(
            id: 'm_2',
            cohortId: 'grp_split',
            userId: user2.id,
            role: 'member',
            joinedAt: DateTime(2026, 1, 2),
            profile: user2,
          ),
        ],
      );
      await container.read(groupsProvider.notifier).createGroup(group);

      // Add expense paid by Alice for Alice and Bob (1000 total, 500 each)
      final expense = Expense(
        id: 'exp_split_1',
        cohortId: 'grp_split',
        title: 'Highway Toll & Food',
        totalAmount: 1000.0,
        paidByUserId: user1.id,
        splits: [
          ExpenseSplit(userId: user1.id, amount: 500.0),
          ExpenseSplit(userId: user2.id, amount: 500.0),
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await container
          .read(groupExpensesProvider('grp_split').notifier)
          .addExpense(expense);

      final totalSpending =
          container.read(groupTotalSpendingProvider('grp_split'));
      expect(totalSpending, equals(1000.0));

      final aliceNetBalance = container.read(userNetBalanceProvider('grp_split'));
      expect(aliceNetBalance, equals(500.0)); // Alice is owed 500

      final debts = container.read(groupDebtsProvider('grp_split'));
      expect(debts.length, equals(1));
      expect(debts.first.fromUserId, equals(user2.id));
      expect(debts.first.toUserId, equals(user1.id));
      expect(debts.first.amount, equals(500.0));
    });

    test('groupNeedsProvider and staleNeedsCountProvider', () async {
      final user = UserProfile(
        id: 'u_lead',
        fullName: 'Lead',
        createdAt: DateTime(2026, 1, 1),
      );
      await container.read(currentUserProvider.notifier).setUser(user);

      final item = await container
          .read(groupNeedsProvider('grp_needs').notifier)
          .addNeed('Paper towels');

      expect(item.title, equals('Paper towels'));
      expect(item.isCompleted, isFalse);

      await container
          .read(groupNeedsProvider('grp_needs').notifier)
          .toggleNeed(item.id);

      final items = container.read(groupNeedsProvider('grp_needs')).value ?? [];
      expect(items.first.isCompleted, isTrue);

      final staleCount = container.read(staleNeedsCountProvider('grp_needs'));
      expect(staleCount, equals(0)); // Completed items are never stale
    });
  });
}

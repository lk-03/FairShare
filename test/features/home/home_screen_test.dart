import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/home/presentation/screens/home_screen.dart';
import 'package:fairshare/features/home/presentation/widgets/create_group_sheet.dart';
import 'package:fairshare/features/home/presentation/widgets/join_group_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testUser = UserProfile(
    id: 'user_1',
    email: 'test@fairshare.app',
    fullName: 'Lokesh Kumar',
    createdAt: DateTime(2026, 1, 1),
  );

  testWidgets('HomeScreen renders header, empty state when no groups exist', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(testUser)),
          groupsProvider.overrideWith(() => _MockEmptyGroupsNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Net Balance display
    expect(find.text('FairShare'), findsOneWidget);
    expect(find.text('PERSONAL • NET BALANCE'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);
    expect(find.text('You are all settled up'), findsOneWidget);

    // Verify Action buttons
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Scan Receipt'), findsOneWidget);
    expect(find.text('Join Group'), findsOneWidget);
    expect(find.text('New Group'), findsOneWidget);

    // Verify Empty state
    expect(find.text('No Groups Yet'), findsOneWidget);
    expect(find.text('No Recent Activity'), findsOneWidget);
  });

  testWidgets('HomeScreen tapping New Group opens CreateGroupSheet', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(testUser)),
          groupsProvider.overrideWith(() => _MockEmptyGroupsNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "New Group"
    await tester.tap(find.text('New Group'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateGroupSheet), findsOneWidget);
    expect(find.text('Create New Group'), findsOneWidget);
    expect(find.text('GROUP NAME'), findsOneWidget);
  });

  testWidgets('HomeScreen tapping Join Group opens JoinGroupSheet', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(testUser)),
          groupsProvider.overrideWith(() => _MockEmptyGroupsNotifier()),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Join Group"
    await tester.tap(find.text('Join Group'));
    await tester.pumpAndSettle();

    expect(find.byType(JoinGroupSheet), findsOneWidget);
    expect(find.text('Join a Group'), findsOneWidget);
    expect(find.text('INVITE CODE'), findsOneWidget);
  });

  testWidgets('HomeScreen computes net balance and renders groups and recent transactions', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    final alexUser = UserProfile(
      id: 'user_1',
      email: 'alex@example.com',
      fullName: 'Alex Vance',
      createdAt: DateTime(2026, 1, 1),
    );

    final samUser = UserProfile(
      id: 'user_2',
      email: 'sam@example.com',
      fullName: 'Sam',
      createdAt: DateTime(2026, 1, 1),
    );

    final mockGroup = Group(
      id: 'group_1',
      name: 'Flat 402 - Bangalore',
      category: 'house',
      currency: 'INR',
      createdBy: 'user_1',
      inviteCode: 'FLAT402',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      members: [
        GroupMember(
          id: 'gm_1',
          cohortId: 'group_1',
          userId: 'user_1',
          role: 'admin',
          joinedAt: DateTime(2026, 1, 1),
          profile: alexUser,
        ),
        GroupMember(
          id: 'gm_2',
          cohortId: 'group_1',
          userId: 'user_2',
          role: 'member',
          joinedAt: DateTime(2026, 1, 1),
          profile: samUser,
        ),
      ],
    );

    final mockExpense = Expense(
      id: 'exp_1',
      cohortId: 'group_1',
      title: 'Groceries at Nature Basket',
      category: 'dining',
      totalAmount: 1200.0,
      paidByUserId: 'user_1',
      paidByName: 'Alex Vance',
      splits: const [
        ExpenseSplit(userId: 'user_1', amount: 600.0),
        ExpenseSplit(userId: 'user_2', amount: 600.0),
      ],
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(alexUser)),
          groupsProvider.overrideWith(() => _MockPopulatedGroupsNotifier([mockGroup])),
          groupExpensesProvider('group_1').overrideWith(
            () => _MockPopulatedExpensesNotifier([mockExpense]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Total net balance: user_1 paid 1200 with 600 personal share -> is owed +₹600.00
    expect(find.text('+₹600.00'), findsOneWidget);
    expect(find.text('Total amount you are owed'), findsOneWidget);

    // Group card rendered
    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('2 members'), findsOneWidget);

    // Recent transaction rendered
    expect(find.text('Groceries at Nature Basket'), findsOneWidget);
  });
}

class _MockCurrentUserNotifier extends CurrentUserNotifier {
  final UserProfile? _user;
  _MockCurrentUserNotifier([this._user]);

  @override
  UserProfile? build() => _user;
}

class _MockEmptyGroupsNotifier extends GroupsNotifier {
  @override
  AsyncValue<List<Group>> build() {
    return const AsyncValue.data([]);
  }

  @override
  Future<void> loadUserGroups() async {}
}

class _MockPopulatedGroupsNotifier extends GroupsNotifier {
  final List<Group> initialGroups;

  _MockPopulatedGroupsNotifier(this.initialGroups);

  @override
  AsyncValue<List<Group>> build() {
    return AsyncValue.data(initialGroups);
  }

  @override
  Future<void> loadUserGroups() async {}
}

class _MockPopulatedExpensesNotifier extends GroupExpensesNotifier {
  final List<Expense> initialExpenses;

  _MockPopulatedExpensesNotifier(this.initialExpenses) : super('dummy');

  @override
  AsyncValue<List<Expense>> build() {
    return AsyncValue.data(initialExpenses);
  }

  @override
  Future<void> loadExpenses() async {}
}

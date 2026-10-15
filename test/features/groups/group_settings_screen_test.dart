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
import 'package:fairshare/features/groups/presentation/screens/group_settings_screen.dart';

class _MockCurrentUser extends CurrentUserNotifier {
  final UserProfile _profile;
  _MockCurrentUser(this._profile);

  @override
  UserProfile? build() => _profile;
}

class _MockGroups extends GroupsNotifier {
  final List<Group> _groups;
  _MockGroups(this._groups);

  @override
  AsyncValue<List<Group>> build() => AsyncValue.data(_groups);

  @override
  Future<bool> kickMember(String groupId, String userId) async {
    final updated = (_groups).map((g) {
      if (g.id == groupId) {
        return g.copyWith(
          members: g.members.where((m) => m.userId != userId).toList(),
        );
      }
      return g;
    }).toList();
    state = AsyncValue.data(updated);
    return true;
  }
}

class _MockExpenses extends GroupExpensesNotifier {
  final List<Expense> _initialExpenses;
  _MockExpenses(super.cohortId, this._initialExpenses);

  @override
  AsyncValue<List<Expense>> build() {
    return AsyncValue.data(_initialExpenses.where((e) => !e.isDeleted).toList());
  }

  @override
  Future<void> restoreExpense(String expenseId) async {
    final current = state.value ?? [];
    final restored = _initialExpenses.where((e) => e.id == expenseId).firstOrNull;
    if (restored != null) {
      state = AsyncValue.data([...current, restored.copyWith(isDeleted: false, clearDeletedAt: true)]);
    }
  }

  @override
  Future<void> purgeExpensePermanently(String expenseId) async {
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((e) => e.id != expenseId).toList());
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testUser = UserProfile(
    id: 'user_1',
    email: 'alex@fairshare.app',
    fullName: 'Alex Vance',
    createdAt: DateTime(2026, 1, 1),
  );

  final memberSam = GroupMember(
    id: 'gm_2',
    cohortId: 'cohort_test_1',
    userId: 'user_sam',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_sam',
      fullName: 'Sam Altman',
      email: 'sam@fairshare.app',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final memberAlex = GroupMember(
    id: 'gm_1',
    cohortId: 'cohort_test_1',
    userId: 'user_1',
    role: 'admin',
    joinedAt: DateTime(2026, 1, 1),
    profile: testUser,
  );

  final testGroup = Group(
    id: 'cohort_test_1',
    name: 'Flat 402 - Bangalore',
    description: 'Roommate splits',
    category: 'house',
    currency: 'INR',
    createdBy: 'user_1',
    inviteCode: 'FLAT402',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    members: [memberAlex, memberSam],
  );

  final testExpense = Expense(
    id: 'exp_test_1',
    cohortId: 'cohort_test_1',
    title: 'Weekly Groceries',
    category: 'dining',
    totalAmount: 1200.0,
    paidByUserId: 'user_1',
    paidByName: 'Alex Vance',
    splitType: SplitType.equal,
    splits: const [
      ExpenseSplit(userId: 'user_1', amount: 600.0),
      ExpenseSplit(userId: 'user_sam', amount: 600.0),
    ],
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
  );

  final deletedExpense = Expense(
    id: 'exp_del_1',
    cohortId: 'cohort_test_1',
    title: 'Old Cab Ride',
    category: 'transport',
    totalAmount: 350.0,
    paidByUserId: 'user_1',
    isDeleted: true,
    deletedAt: DateTime.now().subtract(const Duration(hours: 2)),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  testWidgets('GroupSettingsScreen renders group profile, member live balances, and danger zone',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);
    await cacheService.saveExpenses('cohort_test_1', [testExpense, deletedExpense]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupsProvider.overrideWith(() => _MockGroups([testGroup])),
          groupExpensesProvider('cohort_test_1')
              .overrideWith(() => _MockExpenses('cohort_test_1', [testExpense, deletedExpense])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const GroupSettingsScreen(groupId: 'cohort_test_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Group Profile elements
    expect(find.text('Group Settings'), findsOneWidget);
    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Roommate splits'), findsOneWidget);
    expect(find.text('Members Roster'), findsOneWidget);

    // Verify Member List & Balances
    expect(find.text('Alex Vance (You)'), findsOneWidget);
    expect(find.text('Sam Altman'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Owed ₹600.00'), findsOneWidget);
    expect(find.text('Owes ₹600.00'), findsOneWidget);

    // Verify Import History Section
    expect(find.text('Import History'), findsOneWidget);
    expect(find.text('Import CSV Transactions'), findsOneWidget);
    expect(find.text('Import CSV into Group'), findsOneWidget);

    // Verify Trash Section
    expect(find.text('Expense Trash'), findsOneWidget);
    expect(find.text('Old Cab Ride'), findsOneWidget);
    expect(find.textContaining('22h left to restore'), findsOneWidget);

    // Verify Danger Zone
    expect(find.text('Danger Zone'), findsOneWidget);
    expect(find.text('Leave Group'), findsOneWidget);
    expect(find.text('Delete Group'), findsOneWidget);
  });

  testWidgets('Kicking member with unsettled balance shows warning dialog',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);
    await cacheService.saveExpenses('cohort_test_1', [testExpense]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupsProvider.overrideWith(() => _MockGroups([testGroup])),
          groupExpensesProvider('cohort_test_1')
              .overrideWith(() => _MockExpenses('cohort_test_1', [testExpense])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const GroupSettingsScreen(groupId: 'cohort_test_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find kick button for Sam Altman
    final kickButtons = find.byIcon(Icons.person_remove_rounded);
    expect(kickButtons, findsOneWidget);

    await tester.ensureVisible(kickButtons);
    await tester.tap(kickButtons);
    await tester.pumpAndSettle();

    // Verify unsettled balance warning dialog
    expect(find.text('Unsettled Balance Warning'), findsOneWidget);
    expect(find.textContaining('currently owes ₹600.00'), findsOneWidget);
    expect(find.text('Remove Member'), findsOneWidget);

    // Tap Remove Member
    await tester.tap(find.widgetWithText(ElevatedButton, 'Remove Member'));
    await tester.pumpAndSettle();

    expect(find.textContaining('was removed from the group'), findsOneWidget);
  });

  testWidgets('Restoring deleted expense in trash triggers restore',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.resetPhysicalSize);

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);
    await cacheService.saveExpenses('cohort_test_1', [deletedExpense]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupsProvider.overrideWith(() => _MockGroups([testGroup])),
          groupExpensesProvider('cohort_test_1')
              .overrideWith(() => _MockExpenses('cohort_test_1', [deletedExpense])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const GroupSettingsScreen(groupId: 'cohort_test_1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Old Cab Ride'), findsOneWidget);
    final restoreBtn = find.byIcon(Icons.restore_rounded);
    expect(restoreBtn, findsOneWidget);

    await tester.ensureVisible(restoreBtn);
    await tester.tap(restoreBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('restored to group ledger'), findsOneWidget);
  });
}

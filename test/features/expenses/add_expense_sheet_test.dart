import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/expenses/presentation/widgets/add_expense_sheet.dart';

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

  final memberAlex = GroupMember(
    id: 'gm_1',
    cohortId: 'cohort_test_1',
    userId: 'user_1',
    role: 'admin',
    joinedAt: DateTime(2026, 1, 1),
    profile: testUser,
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

  testWidgets('AddExpenseSheet renders form and allows entering expense details',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupsProvider.overrideWith(() => _MockGroups([testGroup])),
          groupExpensesProvider('cohort_test_1')
              .overrideWith(() => _MockExpenses('cohort_test_1', [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: AddExpenseSheet(cohortId: 'cohort_test_1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and headers
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('EXPENSE TITLE'), findsOneWidget);
    expect(find.text('SPLIT METHOD'), findsOneWidget);

    // Verify split mode chips
    expect(find.text('Equal (=)'), findsOneWidget);
    expect(find.text('Exact (₹)'), findsOneWidget);
    expect(find.text('Percent (%)'), findsOneWidget);
    expect(find.text('Shares (x:y)'), findsOneWidget);

    // Enter title
    final titleField = find.widgetWithText(TextField, 'e.g. Dinner, Groceries, Fuel');
    await tester.enterText(titleField, 'Dinner Party');

    // Enter amount
    final amountField = find.widgetWithText(TextField, '0.00');
    await tester.enterText(amountField, '1000');

    await tester.pumpAndSettle();

    // Verify save button is rendered
    expect(find.text('Save Expense'), findsOneWidget);

    // Tap Save Expense
    await tester.tap(find.text('Save Expense'), warnIfMissed: false);
    await tester.pumpAndSettle();
  });

  testWidgets('AddExpenseSheet switches between split modes', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupsProvider.overrideWith(() => _MockGroups([testGroup])),
          groupExpensesProvider('cohort_test_1')
              .overrideWith(() => _MockExpenses('cohort_test_1', [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: AddExpenseSheet(cohortId: 'cohort_test_1'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Exact split
    await tester.tap(find.text('Exact (₹)'));
    await tester.pumpAndSettle();
    expect(find.text('EXACT AMOUNTS'), findsOneWidget);

    // Switch to Percentage split
    await tester.tap(find.text('Percent (%)'));
    await tester.pumpAndSettle();
    expect(find.text('PERCENTAGES'), findsOneWidget);

    // Switch to Shares split
    await tester.tap(find.text('Shares (x:y)'));
    await tester.pumpAndSettle();
    expect(find.text('SHARES ALLOCATION'), findsOneWidget);
  });
}

class _MockCurrentUser extends CurrentUserNotifier {
  final UserProfile _user;
  _MockCurrentUser(this._user);

  @override
  UserProfile? build() => _user;
}

class _MockGroups extends GroupsNotifier {
  final List<Group> _groups;
  _MockGroups(this._groups);

  @override
  AsyncValue<List<Group>> build() => AsyncValue.data(_groups);

  @override
  Future<void> loadUserGroups() async {}
}

class _MockExpenses extends GroupExpensesNotifier {
  final List<Expense> _expenses;
  _MockExpenses(super.cohortId, this._expenses);

  @override
  AsyncValue<List<Expense>> build() => AsyncValue.data(_expenses);

  @override
  Future<void> loadExpenses() async {}

  @override
  Future<Expense> addExpense(Expense expense) async {
    state = AsyncValue.data([..._expenses, expense]);
    return expense;
  }
}

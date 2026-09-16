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

  testWidgets('AddExpenseSheet renders minimal uncluttered form and allows entering expense details',
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

    // Verify minimal uncluttered headers and elements
    expect(find.text('Add an expense'), findsOneWidget);
    expect(find.text('With '), findsOneWidget);
    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Paid by '), findsOneWidget);
    expect(find.text('you'), findsOneWidget);
    expect(find.text(' and split '), findsOneWidget);
    expect(find.text('equally'), findsOneWidget);

    // Enter title
    final titleField = find.widgetWithText(TextField, 'Enter a description');
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

  testWidgets('AddExpenseSheet opens payer and split sub-sheets', (tester) async {
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

    // Enter amount first so splits and payer have a base
    final amountField = find.widgetWithText(TextField, '0.00');
    await tester.enterText(amountField, '1000');
    await tester.pumpAndSettle();

    // Tap 'you' to open PayerSelectionSheet
    await tester.tap(find.text('you'));
    await tester.pumpAndSettle();

    expect(find.text('Who paid?'), findsOneWidget);
    expect(find.text('Multiple People'), findsOneWidget);

    // Close payer sheet
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // Tap 'equally' to open AdjustSplitSheet
    await tester.tap(find.text('equally'));
    await tester.pumpAndSettle();

    expect(find.text('Adjust split'), findsOneWidget);
    expect(find.text('Unequally'), findsOneWidget);
    expect(find.text('Percent'), findsOneWidget);
    expect(find.text('Shares'), findsOneWidget);

    // Close split sheet
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
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

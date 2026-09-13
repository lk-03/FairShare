import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/direct_debt.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/expenses/presentation/widgets/settle_up_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testUser = UserProfile(
    id: 'user_1',
    email: 'alex@fairshare.app',
    fullName: 'Alex Vance',
    vpaId: 'alex@okaxis',
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
      vpaId: 'sam@okhdfcbank',
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

  final testDebt = const DirectDebt(
    fromUserId: 'user_sam',
    toUserId: 'user_1',
    amount: 600.0,
  );

  testWidgets('SettleUpSheet renders transaction flow, VPA, and records cash settlement',
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
          home: Scaffold(
            body: SettleUpSheet(
              cohortId: 'cohort_test_1',
              debt: testDebt,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Settle Up Balance'), findsOneWidget);

    // Verify Payer & Payee
    expect(find.text('Sam Altman'), findsWidgets);
    expect(find.text('You'), findsWidgets);

    // Verify Amount in TextField
    expect(find.widgetWithText(TextField, '600.00'), findsOneWidget);

    // Verify UPI VPA
    expect(find.text('Payee UPI ID (VPA)'), findsOneWidget);
    expect(find.text('alex@okaxis'), findsOneWidget);

    // Verify Action Buttons
    expect(find.textContaining('Pay with UPI App'), findsOneWidget);
    expect(find.text('Record as Settled (Cash / Paid)'), findsOneWidget);

    // Tap Record as Settled
    await tester.tap(find.text('Record as Settled (Cash / Paid)'));
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

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
import 'package:fairshare/features/profile/presentation/widgets/csv_import_sheet.dart';

class _MockCurrentUserNotifier extends CurrentUserNotifier {
  final UserProfile _profile;
  _MockCurrentUserNotifier(this._profile);

  @override
  UserProfile? build() => _profile;
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<Group> _initial;
  _MockGroupsNotifier(this._initial);

  @override
  AsyncValue<List<Group>> build() => AsyncValue.data(_initial);

  @override
  Future<Group> createGroup(Group group) async {
    final current = state.value ?? [];
    state = AsyncValue.data([...current, group]);
    return group;
  }
}

class _MockGroupExpensesNotifier extends GroupExpensesNotifier {
  final List<Expense> _expenses;
  _MockGroupExpensesNotifier(super.cohortId, this._expenses);

  @override
  AsyncValue<List<Expense>> build() => AsyncValue.data(_expenses);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const sampleCsv = '''Date,Description,Category,Cost,Currency,LK,Njj,KATTU PUCHI,keith james (removed)
2026-03-09,Fans,General,2800.00,INR,-700.00,2100.00,-700.00,-700.00
2026-03-10,Dmart,Household supplies,3800.00,INR,2850.00,-950.00,-950.00,-950.00
2026-03-11,keith j. paid Njj,Payment,110.00,INR,0.00,-110.00,0.00,110.00
2026-03-15,"Instamart(maggi,syrup,curd,banana)",Groceries,390.00,INR,-167.50,-167.50,335.00,0.00
2026-03-18,poori,Dining out,92.00,INR,46.00,-46.00,0.00,0.00
''';

  final testUser = UserProfile(
    id: 'user_lk',
    email: 'lk@fairshare.app',
    fullName: 'LK',
    createdAt: DateTime(2026, 1, 1),
  );

  final testGroup = Group(
    id: 'group_existing_1',
    name: 'Flat 402 - Bangalore',
    currency: 'INR',
    category: 'house',
    inviteCode: 'TEST123',
    createdBy: 'user_lk',
    members: [
      GroupMember(
        id: 'gm_1',
        cohortId: 'group_existing_1',
        userId: 'user_lk',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 1),
        profile: testUser,
      ),
      GroupMember(
        id: 'gm_2',
        cohortId: 'group_existing_1',
        userId: 'user_njj',
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
        originalCsvName: 'Njj',
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  testWidgets('CsvImportSheet New Group flow pastes CSV and maps identity',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(testUser)),
          groupsProvider.overrideWith(() => _MockGroupsNotifier([])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CsvImportSheet.show(ctx),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify Ingestion UI
    expect(find.text('Browse & Import CSV File'), findsOneWidget);
    expect(find.text('New Group'), findsOneWidget);
    expect(find.text('Existing Group'), findsOneWidget);

    // Open paste accordion
    final pasteAccordion = find.text('Or paste CSV text directly');
    await tester.ensureVisible(pasteAccordion);
    await tester.tap(pasteAccordion);
    await tester.pumpAndSettle();

    // Enter CSV text
    final textField = find.byType(TextField);
    await tester.ensureVisible(textField);
    await tester.enterText(textField, sampleCsv);
    await tester.pumpAndSettle();

    // Tap preview
    final previewBtn = find.text('Preview Pasted CSV');
    await tester.ensureVisible(previewBtn);
    await tester.tap(previewBtn);
    await tester.pumpAndSettle();

    // Verify step 1 Preview elements
    expect(find.text('NEW GROUP NAME'), findsOneWidget);
    expect(find.text('WHICH MEMBER IN THIS CSV ARE YOU?'), findsOneWidget);
    expect(find.text('Create Group & Import (5 Expenses)'), findsOneWidget);

    // Verify parsed member names
    expect(find.text('LK'), findsWidgets);
    expect(find.text('Njj'), findsWidgets);
    expect(find.text('keith james'), findsWidgets);
  });

  testWidgets('CsvImportSheet Existing Group flow maps CSV members to existing roster',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(testUser)),
          groupsProvider.overrideWith(() => _MockGroupsNotifier([testGroup])),
          groupExpensesProvider('group_existing_1')
              .overrideWith(() => _MockGroupExpensesNotifier('group_existing_1', [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CsvImportSheet.show(ctx, targetGroup: testGroup),
                  child: const Text('Open Existing Import'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Existing Import'));
    await tester.pumpAndSettle();

    // Verify pre-locked target group banner
    expect(find.text('Target Group'), findsOneWidget);
    expect(find.text('Flat 402 - Bangalore'), findsWidgets);

    // Open paste accordion
    final pasteAccordion = find.text('Or paste CSV text directly');
    await tester.ensureVisible(pasteAccordion);
    await tester.tap(pasteAccordion);
    await tester.pumpAndSettle();

    // Enter CSV text
    final textField = find.byType(TextField);
    await tester.ensureVisible(textField);
    await tester.enterText(textField, sampleCsv);
    await tester.pumpAndSettle();

    // Tap preview
    final previewBtn = find.text('Preview Pasted CSV');
    await tester.ensureVisible(previewBtn);
    await tester.tap(previewBtn);
    await tester.pumpAndSettle();

    // Verify existing group preview
    expect(find.text('Importing into Existing Group'), findsOneWidget);
    expect(find.text('MAP CSV MEMBERS TO GROUP ROSTER'), findsOneWidget);
    expect(find.text('Import History into Flat 402 - Bangalore (5 Expenses)'), findsOneWidget);

    // Verify member mapping dropdowns rendered
    expect(find.text('From CSV'), findsWidgets);
  });
}

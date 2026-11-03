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
}

class _MockGroupExpensesNotifier extends GroupExpensesNotifier {
  final List<Expense> _expenses;
  _MockGroupExpensesNotifier(super.cohortId, this._expenses);

  @override
  AsyncValue<List<Expense>> build() => AsyncValue.data(_expenses);

  @override
  Future<void> loadExpenses() async {
    state = AsyncValue.data(_expenses);
  }
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

  final testGroup2Members = Group(
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

  final testGroup4Members = Group(
    id: 'group_existing_2',
    name: 'Goa Trip 2026',
    currency: 'INR',
    category: 'trip',
    inviteCode: 'GOA123',
    createdBy: 'user_lk',
    members: [
      GroupMember(
        id: 'gm_1',
        cohortId: 'group_existing_2',
        userId: 'user_lk',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 1),
        profile: testUser,
      ),
      GroupMember(
        id: 'gm_2',
        cohortId: 'group_existing_2',
        userId: 'user_njj',
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
        originalCsvName: 'Njj',
      ),
      GroupMember(
        id: 'gm_3',
        cohortId: 'group_existing_2',
        userId: 'user_kattu',
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
        originalCsvName: 'KATTU PUCHI',
      ),
      GroupMember(
        id: 'gm_4',
        cohortId: 'group_existing_2',
        userId: 'user_keith',
        role: 'member',
        joinedAt: DateTime(2026, 1, 1),
        originalCsvName: 'keith james',
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final testLocalGroup = Group(
    id: 'local_outing_123',
    name: 'Weekend Trek',
    currency: 'INR',
    category: 'trip',
    inviteCode: '',
    isLocal: true,
    createdBy: 'user_lk',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  testWidgets('CsvImportSheet blocks import when target group has fewer members than active CSV members',
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
          groupsProvider.overrideWith(() => _MockGroupsNotifier([testGroup2Members])),
          groupExpensesProvider('group_existing_1')
              .overrideWith(() => _MockGroupExpensesNotifier('group_existing_1', [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CsvImportSheet.show(ctx, targetGroup: testGroup2Members),
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

    // Capacity error should block import and show SnackBar
    expect(find.textContaining('Cannot Import: CSV has 4 active members'), findsOneWidget);
    // Should stay on Step 0
    expect(find.text('MAP CSV MEMBERS TO GROUP ROSTER'), findsNothing);
  });

  testWidgets('CsvImportSheet allows import when group has enough active members',
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
          groupsProvider.overrideWith(() => _MockGroupsNotifier([testGroup4Members])),
          groupExpensesProvider('group_existing_2')
              .overrideWith(() => _MockGroupExpensesNotifier('group_existing_2', [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CsvImportSheet.show(ctx, targetGroup: testGroup4Members),
                  child: const Text('Open 4-Member Import'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open 4-Member Import'));
    await tester.pumpAndSettle();

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

    // Step 1 should render successfully
    expect(find.text('Importing into Cloud Group'), findsOneWidget);
    expect(find.text('Goa Trip 2026'), findsWidgets);
    expect(find.text('MAP CSV MEMBERS TO GROUP ROSTER'), findsOneWidget);
    expect(find.text('Active Members'), findsOneWidget);
    expect(find.text('Import History into Goa Trip 2026 (5 Expenses)'), findsOneWidget);

    // Tap Import History button
    final importBtn = find.text('Import History into Goa Trip 2026 (5 Expenses)');
    await tester.ensureVisible(importBtn);
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    // Verify cache updated with 5 expenses
    final saved = cacheService.getCachedExpenses('group_existing_2');
    expect(saved.length, 5);
  });

  testWidgets('CsvImportSheet shows warning banner when target group is a local group',
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
          groupsProvider.overrideWith(() => _MockGroupsNotifier([testLocalGroup])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CsvImportSheet.show(ctx, targetGroup: testLocalGroup),
                  child: const Text('Open Local Import'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Local Import'));
    await tester.pumpAndSettle();

    // Verify Cloud Groups Only warning banner
    expect(find.text('Cloud Groups Only'), findsOneWidget);
    expect(find.textContaining('Weekend Trek'), findsOneWidget);
  });

  testWidgets('CsvImportSheet imports 2 active members (Noel, Kowsic) and 1 shadow member (Suren)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    final mockNoelUser = UserProfile(
      id: 'user_noel',
      email: 'noel@fairshare.app',
      fullName: 'Noel',
      createdAt: DateTime(2026, 1, 1),
    );

    final testGroup2 = Group(
      id: 'group_cloud_2',
      name: 'Hackathon Squad',
      currency: 'INR',
      category: 'event',
      inviteCode: 'HACK123',
      createdBy: 'user_lk',
      members: [
        GroupMember(
          id: 'gm_kowsic',
          cohortId: 'group_cloud_2',
          userId: 'user_lk',
          role: 'admin',
          joinedAt: DateTime(2026, 1, 1),
          profile: testUser,
        ),
        GroupMember(
          id: 'gm_noel',
          cohortId: 'group_cloud_2',
          userId: 'user_noel',
          role: 'member',
          joinedAt: DateTime(2026, 1, 1),
          profile: mockNoelUser,
        ),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    const mock3PersonCsv = '''Date,Description,Category,Cost,Currency,Noel,Kowsic,Suren
2026-10-20,Team Lunch,Food,900.00,INR,600.00,-300.00,-300.00
2026-10-21,Cab Ride,Transport,600.00,INR,-300.00,0.00,300.00
''';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(testUser)),
          groupsProvider.overrideWith(() => _MockGroupsNotifier([testGroup2])),
          groupExpensesProvider('group_cloud_2')
              .overrideWith(() => _MockGroupExpensesNotifier('group_cloud_2', [])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => CsvImportSheet.show(ctx, targetGroup: testGroup2),
                  child: const Text('Open 3-Person Import'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open 3-Person Import'));
    await tester.pumpAndSettle();

    // Paste CSV
    final pasteHeader = find.text('Or paste CSV text directly');
    await tester.ensureVisible(pasteHeader);
    await tester.tap(pasteHeader);
    await tester.pumpAndSettle();

    final inputField = find.byType(TextField);
    await tester.ensureVisible(inputField);
    await tester.enterText(inputField, mock3PersonCsv);
    await tester.pumpAndSettle();

    // Tap Preview
    final previewBtn = find.text('Preview Pasted CSV');
    await tester.ensureVisible(previewBtn);
    await tester.tap(previewBtn);
    await tester.pumpAndSettle();

    // Step 1: Verify Noel and Kowsic are active, Suren is settled
    expect(find.text('MAP CSV MEMBERS TO GROUP ROSTER'), findsOneWidget);
    expect(find.text('Noel'), findsWidgets);
    expect(find.text('Kowsic'), findsWidgets);
    expect(find.text('Suren'), findsWidgets);
    expect(find.text('+ New Shadow Member'), findsOneWidget);

    // Tap Import History button
    final importBtn = find.text('Import History into Hackathon Squad (2 Expenses)');
    await tester.ensureVisible(importBtn);
    await tester.tap(importBtn);
    await tester.pumpAndSettle();

    // Verify cache updated with 2 expenses
    final saved = cacheService.getCachedExpenses('group_cloud_2');
    expect(saved.length, 2);
  });
}

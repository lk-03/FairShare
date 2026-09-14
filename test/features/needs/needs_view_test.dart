import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/need_item.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/data/providers/needs_provider.dart';
import 'package:fairshare/features/groups/presentation/screens/group_detail_screen.dart';
import 'package:fairshare/features/needs/presentation/widgets/needs_list_view.dart';
import 'package:fairshare/features/needs/presentation/widgets/needs_reminder_settings_sheet.dart';
import 'package:fairshare/features/needs/presentation/widgets/stale_needs_reminder_sheet.dart';

void main() {
  late SharedPreferences prefs;
  late LocalCacheService cacheService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
  });

  final testUser = UserProfile(
    id: 'user_1',
    email: 'alex@fairshare.app',
    fullName: 'Alex Vance',
    createdAt: DateTime(2026, 1, 1),
  );

  final testGroup = Group(
    id: 'cohort_1',
    name: 'Flat 402 - Bangalore',
    description: 'Roommate split expenses',
    category: 'house',
    currency: 'INR',
    createdBy: 'user_1',
    inviteCode: 'FLAT402',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    members: [
      GroupMember(
        id: 'gm_1',
        cohortId: 'cohort_1',
        userId: 'user_1',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 1),
        profile: testUser,
      ),
    ],
  );

  final testFreshItem = NeedItem(
    id: 'need_fresh_1',
    cohortId: 'cohort_1',
    title: 'Oat Milk 1L',
    addedByUserId: 'user_1',
    addedByName: 'Alex Vance',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(hours: 4)),
  );

  final testStaleItem = NeedItem(
    id: 'need_stale_1',
    cohortId: 'cohort_1',
    title: 'AA Batteries',
    addedByUserId: 'user_2',
    addedByName: 'Sam Altman',
    isCompleted: false,
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
  );

  final testBoughtItem = NeedItem(
    id: 'need_bought_1',
    cohortId: 'cohort_1',
    title: 'Dishwasher Pods',
    addedByUserId: 'user_3',
    addedByName: 'Bob Dylan',
    isCompleted: true,
    completedAt: DateTime.now().subtract(const Duration(days: 1)),
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  Widget buildTestScope({
    required Widget child,
    List<NeedItem>? needs,
    Function(String)? onAddNeed,
    Function(String)? onToggleNeed,
    Function(String)? onDeleteNeed,
  }) {
    final items = needs ?? [testFreshItem, testStaleItem, testBoughtItem];

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localCacheServiceProvider.overrideWithValue(cacheService),
        currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
        groupsProvider.overrideWith(() => _MockGroupsNotifier([testGroup])),
        groupExpensesProvider('cohort_1')
            .overrideWith(() => _MockExpenses('cohort_1', [])),
        groupNeedsProvider('cohort_1').overrideWith(
          () => _MockGroupNeedsNotifier(
            items,
            onAdd: onAddNeed,
            onToggle: onToggleNeed,
            onDelete: onDeleteNeed,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('NeedsListView renders banner, input bar, and items checklist', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(child: const SingleChildScrollView(child: NeedsListView(cohortId: 'cohort_1'))),
    );
    await tester.pumpAndSettle();

    // Verify banner and Quick Add
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Add needed item (e.g. Milk, Bread)...'), findsOneWidget);

    // Verify filter pills
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('Pending (2)'), findsOneWidget);
    expect(find.text('Bought (1)'), findsOneWidget);

    // Verify items
    expect(find.text('Oat Milk 1L'), findsOneWidget);
    expect(find.text('Added by You'), findsOneWidget);

    // Stale item
    expect(find.text('AA Batteries'), findsOneWidget);
    expect(find.text('4d pending'), findsOneWidget);
    expect(find.text('Added 4d ago • Waiting to be bought'), findsOneWidget);

    // Bought item
    expect(find.text('Dishwasher Pods'), findsOneWidget);
    expect(find.text('4d left'), findsOneWidget);
  });

  testWidgets('NeedsListView allows filtering by status pill', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(child: const SingleChildScrollView(child: NeedsListView(cohortId: 'cohort_1'))),
    );
    await tester.pumpAndSettle();

    // Tap Pending
    await tester.tap(find.text('Pending (2)'));
    await tester.pumpAndSettle();

    expect(find.text('Oat Milk 1L'), findsOneWidget);
    expect(find.text('AA Batteries'), findsOneWidget);
    expect(find.text('Dishwasher Pods'), findsNothing);

    // Tap Bought
    await tester.tap(find.text('Bought (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Oat Milk 1L'), findsNothing);
    expect(find.text('AA Batteries'), findsNothing);
    expect(find.text('Dishwasher Pods'), findsOneWidget);
  });

  testWidgets('NeedsListView triggers add, toggle, and delete callbacks', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? addedTitle;
    String? toggledId;
    String? deletedId;

    await tester.pumpWidget(
      buildTestScope(
        child: const SingleChildScrollView(child: NeedsListView(cohortId: 'cohort_1')),
        onAddNeed: (t) => addedTitle = t,
        onToggleNeed: (id) => toggledId = id,
        onDeleteNeed: (id) => deletedId = id,
      ),
    );
    await tester.pumpAndSettle();

    // Add item
    final inputField = find.byType(TextField);
    await tester.enterText(inputField, 'Brown Sourdough Bread');
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(addedTitle, 'Brown Sourdough Bread');

    // Toggle item
    final oatMilkCard = find.ancestor(
      of: find.text('Oat Milk 1L'),
      matching: find.byType(Container),
    ).first;
    final oatMilkCheckbox = find.descendant(
      of: oatMilkCard,
      matching: find.byIcon(Icons.check_box_outline_blank_rounded),
    );
    await tester.tap(oatMilkCheckbox);
    await tester.pumpAndSettle();
    expect(toggledId, 'need_fresh_1');

    // Delete item
    final oatMilkDelete = find.descendant(
      of: oatMilkCard,
      matching: find.byIcon(Icons.delete_outline_rounded),
    );
    await tester.tap(oatMilkDelete);
    await tester.pumpAndSettle();
    expect(deletedId, 'need_fresh_1');
  });

  testWidgets('NeedsReminderSettingsSheet configures and saves frequency preferences', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(
        child: const NeedsReminderSettingsSheet(cohortId: 'cohort_1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notification & Reminder Settings'), findsOneWidget);
    expect(find.text('Enable Reminders'), findsOneWidget);
    expect(find.text('Every X Hours'), findsOneWidget);
    expect(find.text('Every X Days'), findsOneWidget);

    // Tap 8h chip
    await tester.tap(find.text('8h'));
    await tester.pumpAndSettle();

    // Switch to Days
    await tester.tap(find.text('Every X Days'));
    await tester.pumpAndSettle();

    expect(find.text('INTERVAL IN DAYS'), findsOneWidget);
    expect(find.text('NOTIFICATION TIME'), findsOneWidget);

    // Tap 3d and Night
    await tester.tap(find.text('3d'));
    await tester.tap(find.text('Night (9 PM)'));
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Save Preferences'));
    await tester.pumpAndSettle();

    final saved = cacheService.getCachedReminderSettings('cohort_1');
    expect(saved?.frequencyUnit, 'days');
    expect(saved?.frequencyDays, 3);
    expect(saved?.reminderTime, '21:00');
  });

  testWidgets('StaleNeedsReminderSheet renders overdue items with 1-tap Bought action', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? boughtId;

    await tester.pumpWidget(
      buildTestScope(
        child: const StaleNeedsReminderSheet(cohortId: 'cohort_1'),
        onToggleNeed: (id) => boughtId = id,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pending House Needs'), findsOneWidget);
    expect(find.text('AA Batteries'), findsOneWidget);
    expect(find.text('Flat 402 - Bangalore • Added 4d ago'), findsOneWidget);
    expect(find.text('Bought'), findsOneWidget);

    // Tap Bought
    await tester.tap(find.text('Bought'));
    await tester.pumpAndSettle();
    expect(boughtId, 'need_stale_1');

    // Dismiss
    await tester.tap(find.text('Got it / Dismiss'));
    await tester.pumpAndSettle();
  });

  testWidgets('GroupDetailScreen switches between General Ledger and House Cart tabs', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestScope(
        child: const GroupDetailScreen(groupId: 'cohort_1'),
      ),
    );
    await tester.pumpAndSettle();

    // Initially on General Ledger
    expect(find.text('General Ledger'), findsOneWidget);
    expect(find.text('House Cart'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // Pending items badge
    expect(find.textContaining('MEMBERS'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);

    // Tap House Cart tab
    await tester.tap(find.text('House Cart'));
    await tester.pumpAndSettle();

    // Verify House Cart is active
    expect(find.byType(NeedsListView), findsOneWidget);
    expect(find.text('Oat Milk 1L'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing); // FAB hidden on House Cart tab

    // Switch back to General Ledger
    await tester.tap(find.text('General Ledger'));
    await tester.pumpAndSettle();

    expect(find.textContaining('MEMBERS'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

class _MockCurrentUser extends CurrentUserNotifier {
  final UserProfile _user;
  _MockCurrentUser(this._user);

  @override
  UserProfile? build() => _user;
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<Group> _groups;
  _MockGroupsNotifier(this._groups);

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
}

class _MockGroupNeedsNotifier extends GroupNeedsNotifier {
  final List<NeedItem> _initialItems;
  final Function(String)? onAdd;
  final Function(String)? onToggle;
  final Function(String)? onDelete;

  _MockGroupNeedsNotifier(
    this._initialItems, {
    this.onAdd,
    this.onToggle,
    this.onDelete,
  }) : super('cohort_1');

  @override
  AsyncValue<List<NeedItem>> build() => AsyncValue.data(_initialItems);

  @override
  Future<void> loadNeeds() async {}

  @override
  Future<NeedItem> addNeed(String title) async {
    onAdd?.call(title);
    final newItem = NeedItem(
      id: 'need_${DateTime.now().millisecondsSinceEpoch}',
      cohortId: 'cohort_1',
      title: title,
      addedByUserId: 'user_1',
      createdAt: DateTime.now(),
    );
    final current = state.value ?? [];
    state = AsyncValue.data([newItem, ...current]);
    return newItem;
  }

  @override
  Future<void> toggleNeed(String itemId) async {
    onToggle?.call(itemId);
    final current = state.value ?? [];
    state = AsyncValue.data(current.map((i) {
      if (i.id == itemId) {
        return i.copyWith(isCompleted: !i.isCompleted);
      }
      return i;
    }).toList());
  }

  @override
  Future<void> deleteNeed(String itemId) async {
    onDelete?.call(itemId);
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((i) => i.id != itemId).toList());
  }
}

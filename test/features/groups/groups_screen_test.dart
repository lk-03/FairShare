import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/groups/presentation/screens/groups_screen.dart';
import 'package:fairshare/features/groups/presentation/widgets/group_action_sheet.dart';

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

  final testOtherMember = GroupMember(
    id: 'gm_2',
    cohortId: 'cohort_1',
    userId: 'user_2',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_2',
      email: 'sam@fairshare.app',
      fullName: 'Sam Altman',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final testActiveGroup1 = Group(
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
      testOtherMember,
    ],
  );

  final testActiveGroup2 = Group(
    id: 'cohort_2',
    name: 'Goa Weekend Trip',
    description: 'Beach resort & transport',
    category: 'trip',
    currency: 'INR',
    createdBy: 'user_1',
    inviteCode: 'GOA2026',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    members: [
      GroupMember(
        id: 'gm_3',
        cohortId: 'cohort_2',
        userId: 'user_1',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 1),
        profile: testUser,
      ),
    ],
  );

  final testDeletedGroup = Group(
    id: 'cohort_3_del',
    name: 'Old College Roadtrip',
    description: 'Archived memories',
    category: 'trip',
    currency: 'INR',
    createdBy: 'user_1',
    inviteCode: 'OLD2025',
    isDeleted: true,
    deletedAt: DateTime.now().subtract(const Duration(days: 3)),
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
    members: [],
  );

  Widget buildTestWidget({
    List<Group>? groups,
    Map<String, double>? netBalances,
    Function(String)? onRestoreGroup,
    Function(String)? onDeletePermanently,
    Function(String)? onToggleArchive,
  }) {
    final groupsList = groups ?? [testActiveGroup1, testActiveGroup2, testDeletedGroup];

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localCacheServiceProvider.overrideWithValue(cacheService),
        currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
        groupsProvider.overrideWith(() => _MockGroupsNotifier(
              groupsList,
              onRestore: onRestoreGroup,
              onDeleteForever: onDeletePermanently,
              onToggleArchive: onToggleArchive,
            )),
        if (netBalances != null)
          ...netBalances.entries.map(
            (e) => userNetBalanceProvider(e.key).overrideWithValue(e.value),
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: const GroupsScreen(),
      ),
    );
  }

  testWidgets('GroupsScreen renders active cohorts list, balances, and members', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestWidget(
        netBalances: {
          'cohort_1': 450.00,
          'cohort_2': -120.50,
        },
      ),
    );
    await tester.pumpAndSettle();

    // Verify Screen Title & Count badge
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('EVENT COHORTS & SHARED LEDGERS'), findsOneWidget);
    expect(find.text('2 Active'), findsOneWidget);

    // Verify Active Groups
    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Roommate split expenses'), findsOneWidget);
    expect(find.text('You & Sam Altman'), findsOneWidget);
    expect(find.text('+₹450.00'), findsOneWidget);

    expect(find.text('Goa Weekend Trip'), findsOneWidget);
    expect(find.text('Beach resort & transport'), findsOneWidget);
    expect(find.text('-₹120.50'), findsOneWidget);
  });

  testWidgets('GroupsScreen filters cohorts by search input', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Goa Weekend Trip'), findsOneWidget);

    // Search for "Goa"
    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Goa');
    await tester.pumpAndSettle();

    expect(find.text('Flat 402 - Bangalore'), findsNothing);
    expect(find.text('Goa Weekend Trip'), findsOneWidget);

    // Search for non-existent group
    await tester.enterText(searchField, 'NonExistentXYZ');
    await tester.pumpAndSettle();

    expect(find.text('No Matching Groups'), findsOneWidget);
  });

  testWidgets('GroupsScreen filters cohorts by category chip', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Tap "Trip" category chip
    await tester.tap(find.text('Trip'));
    await tester.pumpAndSettle();

    expect(find.text('Flat 402 - Bangalore'), findsNothing);
    expect(find.text('Goa Weekend Trip'), findsOneWidget);

    // Tap "House" category chip
    await tester.tap(find.text('House'));
    await tester.pumpAndSettle();

    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Goa Weekend Trip'), findsNothing);

    // Tap "All" chip
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Goa Weekend Trip'), findsOneWidget);
  });

  testWidgets('GroupsScreen Speed-Dial FAB toggles and displays actions', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Join Group'), findsNothing);
    expect(find.text('New Event Cohort'), findsNothing);

    // Tap FAB
    final fabFinder = find.byType(FloatingActionButton);
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    expect(find.text('Join Group'), findsOneWidget);
    expect(find.text('New Event Cohort'), findsOneWidget);

    // Tap FAB again to close
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();

    expect(find.text('Join Group'), findsNothing);
    expect(find.text('New Event Cohort'), findsNothing);
  });

  testWidgets('Trash accordion expands, restores group and confirms permanent deletion', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool restoreCalled = false;
    bool deleteForeverCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        onRestoreGroup: (id) => restoreCalled = true,
        onDeletePermanently: (id) => deleteForeverCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    // Verify Trash Accordion Header
    expect(find.text('TRASH / SCHEDULED FOR DELETION (1)'), findsOneWidget);
    expect(find.text('Old College Roadtrip'), findsNothing);

    // Expand accordion
    await tester.tap(find.text('TRASH / SCHEDULED FOR DELETION (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Old College Roadtrip'), findsOneWidget);
    expect(find.text('Deletes in 12 days'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete Now'), findsOneWidget);

    // Tap Restore
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    expect(restoreCalled, isTrue);

    // Tap Delete Now and confirm
    await tester.tap(find.text('Delete Now'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Permanently'), findsOneWidget);
    expect(find.text('Delete Forever'), findsOneWidget);

    await tester.tap(find.text('Delete Forever'));
    await tester.pumpAndSettle();
    expect(deleteForeverCalled, isTrue);
  });

  testWidgets('GroupActionSheet displays quick actions and triggers archive toggle', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool toggleArchiveCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        onToggleArchive: (id) => toggleArchiveCalled = true,
      ),
    );
    await tester.pumpAndSettle();

    // Long-press on Flat 402 card
    await tester.longPress(find.text('Flat 402 - Bangalore'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupActionSheet), findsOneWidget);
    expect(find.text('Invite Members'), findsOneWidget);
    expect(find.text('Edit Group'), findsOneWidget);
    expect(find.text('Archive Group'), findsOneWidget);
    expect(find.text('Delete Group'), findsOneWidget);

    // Tap Archive Group
    await tester.tap(find.text('Archive Group'));
    await tester.pumpAndSettle();

    expect(toggleArchiveCalled, isTrue);
  });
}

class _MockCurrentUser extends CurrentUserNotifier {
  final UserProfile _user;
  _MockCurrentUser(this._user);

  @override
  UserProfile? build() => _user;
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<Group> _initialGroups;
  final Function(String)? onRestore;
  final Function(String)? onDeleteForever;
  final Function(String)? onToggleArchive;

  _MockGroupsNotifier(
    this._initialGroups, {
    this.onRestore,
    this.onDeleteForever,
    this.onToggleArchive,
  });

  @override
  AsyncValue<List<Group>> build() => AsyncValue.data(_initialGroups);

  @override
  Future<void> loadUserGroups() async {}

  @override
  Future<void> restoreGroup(String groupId) async {
    onRestore?.call(groupId);
  }

  @override
  Future<void> deleteGroupPermanently(String groupId) async {
    onDeleteForever?.call(groupId);
  }

  @override
  Future<void> toggleArchiveGroup(String groupId) async {
    onToggleArchive?.call(groupId);
  }
}

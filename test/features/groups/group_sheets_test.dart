import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/friend.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/friends_provider.dart';
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/groups/presentation/widgets/add_friends_to_group_sheet.dart';
import 'package:fairshare/features/groups/presentation/widgets/edit_group_sheet.dart';
import 'package:fairshare/features/groups/presentation/widgets/group_qr_sheet.dart';
import 'package:fairshare/features/home/presentation/widgets/join_group_sheet.dart';

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
    members: [
      GroupMember(
        id: 'gm_1',
        cohortId: 'cohort_test_1',
        userId: 'user_1',
        role: 'admin',
        joinedAt: DateTime(2026, 1, 1),
        profile: testUser,
      ),
    ],
  );

  testWidgets('GroupQrSheet renders group invite code and copy action', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: GroupQrSheet(group: testGroup),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Flat 402 - Bangalore'), findsOneWidget);
    expect(find.text('Scan QR code or share invite code to join cohort'), findsOneWidget);
    expect(find.text('FLAT402'), findsOneWidget);
    expect(find.byTooltip('Copy Code'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy Code'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('EditGroupSheet renders form and updates group', (tester) async {
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
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: EditGroupSheet(group: testGroup),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Edit Group'), findsOneWidget);
    expect(find.text('GROUP NAME'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Delete Group'), findsOneWidget);

    final nameField = find.widgetWithText(TextField, 'Flat 402 - Bangalore');
    await tester.enterText(nameField, 'Flat 402 Renovated');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
  });

  testWidgets('JoinGroupSheet renders QR scan card, manual input, and fires onScanQr', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool scanQrFired = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: JoinGroupSheet(
            onScanQr: () => scanQrFired = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Join a Group'), findsOneWidget);
    expect(find.text('Scan Group QR Code'), findsOneWidget);
    expect(find.text("Point your camera at a friend's invite QR"), findsOneWidget);
    expect(find.text('OR ENTER CODE MANUALLY'), findsOneWidget);
    expect(find.text('INVITE CODE'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsWidgets);
    expect(find.text('Join Group'), findsOneWidget);

    // Tap Scan Group QR Code card
    await tester.tap(find.text('Scan Group QR Code'));
    await tester.pumpAndSettle();

    expect(scanQrFired, isTrue);
  });

  testWidgets('AddFriendsToGroupSheet renders mutual friends, allows selection, and submits', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);

    final now = DateTime(2026, 1, 1);
    final friend1 = Friend(
      id: 'f_mutual_1',
      friendUserId: 'user_friend_1',
      profile: UserProfile(
        id: 'user_friend_1',
        fullName: 'Tara Sharma',
        username: 'tara_s',
        email: 'tara@example.com',
        createdAt: now,
      ),
      status: FriendshipStatus.accepted,
      createdBy: 'user_1',
      isLocal: false,
      createdAt: now,
      updatedAt: now,
    );

    // Friend who is already a member of testGroup (should NOT appear in available list)
    final friendAlreadyInGroup = Friend(
      id: 'f_already_in',
      friendUserId: 'user_1', // same as testGroup.members[0].userId
      profile: testUser,
      status: FriendshipStatus.accepted,
      createdBy: 'user_1',
      isLocal: false,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          friendsProvider.overrideWith(() => _MockFriendsNotifier([friend1, friendAlreadyInGroup])),
          groupsProvider.overrideWith(() => _MockGroups([testGroup])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: AddFriendsToGroupSheet(group: testGroup),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify title and description
    expect(find.text('Add Friends to Group'), findsOneWidget);
    expect(find.text('Add mutual friends into "Flat 402 - Bangalore"'), findsOneWidget);

    // Tara Sharma should be displayed
    expect(find.text('Tara Sharma'), findsOneWidget);

    // user_1 is already in group, so Alex Vance should NOT appear in the selection list
    expect(find.text('Alex Vance'), findsNothing);

    // Initial button state: 0 selected
    expect(find.text('Select Friends to Add'), findsOneWidget);

    // Tap Tara Sharma to select
    await tester.tap(find.text('Tara Sharma'));
    await tester.pumpAndSettle();

    // Button should update to 1 selected
    expect(find.text('Add 1 Friend'), findsOneWidget);

    // Tap submit button
    await tester.tap(find.text('Add 1 Friend'));
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

  @override
  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {}

  @override
  Future<List<GroupMember>> addFriendsToGroup(String groupId, List<Friend> friends) async => [];
}

class _MockFriendsNotifier extends FriendsNotifier {
  final List<Friend> _friends;
  _MockFriendsNotifier(this._friends);

  @override
  Future<List<Friend>> build() async => _friends;
}

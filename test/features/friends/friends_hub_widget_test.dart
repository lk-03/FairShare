import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/friend.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/data/local/local_cache_service.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/friends_provider.dart';
import 'package:fairshare/features/friends/presentation/screens/friends_activity_hub_screen.dart';
import 'package:fairshare/features/friends/presentation/widgets/friend_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalCacheService cacheService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = LocalCacheService(prefs);
  });

  testWidgets('FriendsActivityHubScreen renders header and segmented switcher', (tester) async {
    final now = DateTime.now();
    final testFriends = [
      Friend(
        id: 'friend_1',
        friendUserId: 'user_1',
        profile: UserProfile(
          id: 'user_1',
          fullName: 'Ananya Roy',
          email: 'ananya@example.com',
          createdAt: now,
        ),
        isLocal: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          friendsProvider.overrideWith(() => _MockFriendsNotifier(testFriends)),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const FriendsActivityHubScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Hub title and Segment buttons
    expect(find.text('Hub'), findsOneWidget);
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Activity'), findsWidgets);

    // Verify friend card renders
    expect(find.byType(FriendCard), findsOneWidget);
    expect(find.text('Ananya Roy'), findsOneWidget);

    // Tap Activity segment
    await tester.tap(find.text('Activity').first);
    await tester.pumpAndSettle();

    // Activity feed segment should now be active
    expect(find.text('Activity'), findsWidgets);
  });

  testWidgets('FriendsActivityHubScreen displays requests sections and hides emails for non-friends', (tester) async {
    final now = DateTime.now();
    final testFriends = [
      Friend(
        id: 'req_in_1',
        friendUserId: 'user_req',
        profile: UserProfile(
          id: 'user_req',
          fullName: 'Rohan Verma',
          username: 'rohan_v',
          email: 'rohan.secret@example.com',
          createdAt: now,
        ),
        status: FriendshipStatus.pending,
        createdBy: 'user_req',
        isLocal: false,
        createdAt: now,
        updatedAt: now,
      ),
      Friend(
        id: 'req_out_1',
        friendUserId: 'user_out',
        profile: UserProfile(
          id: 'user_out',
          fullName: 'Sneha Rao',
          username: 'sneha_r',
          email: 'sneha.secret@example.com',
          createdAt: now,
        ),
        status: FriendshipStatus.pending,
        createdBy: 'test_current_user',
        isLocal: false,
        createdAt: now,
        updatedAt: now,
      ),
      Friend(
        id: 'friend_acc_1',
        friendUserId: 'user_acc',
        profile: UserProfile(
          id: 'user_acc',
          fullName: 'Kavita Iyer',
          username: 'kavita_i',
          email: 'kavita@example.com',
          createdAt: now,
        ),
        status: FriendshipStatus.accepted,
        createdBy: 'test_current_user',
        isLocal: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          localCacheServiceProvider.overrideWithValue(cacheService),
          currentUserProvider.overrideWith(() => _MockCurrentUserNotifier(UserProfile(
            id: 'test_current_user',
            fullName: 'Current User',
            createdAt: now,
          ))),
          friendsProvider.overrideWith(() => _MockFriendsNotifier(testFriends)),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const FriendsActivityHubScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify incoming requests section
    expect(find.text('Friend Requests (1)'), findsOneWidget);
    expect(find.text('Rohan Verma'), findsOneWidget);
    expect(find.text('@rohan_v'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);

    // Verify outgoing requests section
    expect(find.text('Sent Requests Pending (1)'), findsOneWidget);
    expect(find.text('Sneha Rao'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Verify accepted friends section
    expect(find.text('Kavita Iyer'), findsOneWidget);

    // Strict Privacy verification: Non-friend emails MUST NOT be displayed
    expect(find.text('rohan.secret@example.com'), findsNothing);
    expect(find.text('sneha.secret@example.com'), findsNothing);
  });
}

class _MockCurrentUserNotifier extends CurrentUserNotifier {
  final UserProfile? user;
  _MockCurrentUserNotifier(this.user);

  @override
  UserProfile? build() => user;
}

class _MockFriendsNotifier extends FriendsNotifier {
  final List<Friend> initialFriends;
  _MockFriendsNotifier(this.initialFriends);

  @override
  Future<List<Friend>> build() async => initialFriends;
}

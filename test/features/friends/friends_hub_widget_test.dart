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
}

class _MockFriendsNotifier extends FriendsNotifier {
  final List<Friend> initialFriends;
  _MockFriendsNotifier(this.initialFriends);

  @override
  Future<List<Friend>> build() async => initialFriends;
}

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
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/features/groups/presentation/widgets/edit_group_sheet.dart';
import 'package:fairshare/features/groups/presentation/widgets/group_qr_sheet.dart';

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
}

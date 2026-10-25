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
import 'package:fairshare/data/providers/groups_provider.dart';
import 'package:fairshare/data/repositories/group_repository.dart';
import 'package:fairshare/data/repositories/profile_repository.dart';
import 'package:fairshare/data/services/supabase_service.dart';
import 'package:fairshare/features/groups/presentation/widgets/create_local_group_sheet.dart';
import 'package:fairshare/features/groups/presentation/widgets/local_groups_hub_sheet.dart';
import 'package:fairshare/features/groups/presentation/widgets/settlement_invoice_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testLocalGroup = Group(
    id: 'local_cohort_1',
    name: 'Goa Weekend Trip',
    category: 'trip',
    currency: 'INR',
    createdBy: 'local_user_me',
    inviteCode: 'LOCAL123',
    createdAt: DateTime(2026, 2, 1),
    updatedAt: DateTime(2026, 2, 1),
    isLocal: true,
    members: [
      GroupMember(
        id: 'gm_local_1',
        cohortId: 'local_cohort_1',
        userId: 'local_user_me',
        role: 'admin',
        joinedAt: DateTime(2026, 2, 1),
        profile: UserProfile(
          id: 'local_user_me',
          fullName: 'Me',
          createdAt: DateTime(2026, 2, 1),
        ),
      ),
      GroupMember(
        id: 'gm_local_2',
        cohortId: 'local_cohort_1',
        userId: 'local_user_sam',
        role: 'member',
        joinedAt: DateTime(2026, 2, 1),
        profile: UserProfile(
          id: 'local_user_sam',
          fullName: 'Sam',
          createdAt: DateTime(2026, 2, 1),
        ),
      ),
    ],
  );

  testWidgets('LocalGroupsHubSheet renders empty state when no local groups exist', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupsProvider.overrideWith(() => _MockGroupsNotifier([])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: LocalGroupsHubSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Quick Groups'), findsOneWidget);
    expect(find.text('No Quick Groups Yet'), findsOneWidget);
    expect(find.text('New Quick Group'), findsOneWidget);
  });

  testWidgets('LocalGroupsHubSheet renders local groups list when present', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupsProvider.overrideWith(() => _MockGroupsNotifier([testLocalGroup])),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: const Scaffold(
            body: LocalGroupsHubSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Goa Weekend Trip'), findsOneWidget);
    expect(find.text('2 people'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
  });

  testWidgets('CreateLocalGroupSheet allows inputting group details and adding participant chips', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: CreateLocalGroupSheet(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('New Quick Group'), findsOneWidget);
    expect(find.text('Local offline group'), findsOneWidget);

    // Enter Quick Group Name
    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Dinner with Friends');
    await tester.pumpAndSettle();

    // Add first participant: "Alice"
    final addParticipantField = find.byType(TextField).at(1);
    await tester.enterText(addParticipantField, 'Alice');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Add second participant: "Rahul"
    await tester.enterText(addParticipantField, 'Rahul');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Verify chips: "Alice" and "Rahul"
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);
  });

  testWidgets('SettlementInvoiceCard renders header, participant totals, debts, and UPI details', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final debt = DirectDebt(
      fromUserId: 'local_user_sam',
      toUserId: 'local_user_me',
      amount: 450.0,
    );

    final expense = Expense(
      id: 'exp_1',
      cohortId: 'local_cohort_1',
      title: 'Beach Dinner',
      totalAmount: 900.0,
      paidByUserId: 'local_user_me',
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettlementInvoiceCard(
              group: testLocalGroup,
              expenses: [expense],
              debts: [debt],
              memberBalances: const {
                'local_user_me': 450.0,
                'local_user_sam': -450.0,
              },
              members: testLocalGroup.members,
              organizerVpa: 'fairshare.organizer@okaxis',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Goa Weekend Trip'), findsOneWidget);
    expect(find.text('FAIRSHARE'), findsOneWidget);
    expect(find.text('Settlement Invoice & Summary'), findsOneWidget);
    expect(find.text('Pay via UPI: fairshare.organizer@okaxis'), findsOneWidget);
    expect(find.text('WHO PAYS WHOM'), findsOneWidget);
    expect(find.text('Sam'), findsWidgets);
    expect(find.text('Me'), findsWidgets);
  });

  test('GroupRepository correctly adds, renames, and removes members for local cohorts in cache', () async {
    final prefs = await SharedPreferences.getInstance();
    final cacheService = LocalCacheService(prefs);
    final repo = GroupRepository(
      supabaseService: SupabaseService(),
      profileRepository: ProfileRepository(
        supabaseService: SupabaseService(),
        cacheService: cacheService,
      ),
      cacheService: cacheService,
    );

    await cacheService.saveGroups([testLocalGroup]);
    await cacheService.saveMembers(testLocalGroup.id, testLocalGroup.members);

    // 1. Rename Sam to Samantha
    final renamed = await repo.renameMemberInCohort(
      testLocalGroup.id,
      'local_user_sam',
      'Samantha',
    );
    expect(renamed, isTrue);

    final membersAfterRename = cacheService.getCachedMembers(testLocalGroup.id);
    expect(membersAfterRename.firstWhere((m) => m.userId == 'local_user_sam').displayName, 'Samantha');

    final cachedGroupAfterRename = cacheService.getCachedGroups().firstWhere((g) => g.id == testLocalGroup.id);
    expect(cachedGroupAfterRename.members.firstWhere((m) => m.userId == 'local_user_sam').displayName, 'Samantha');

    // 2. Add a new member
    final newMember = GroupMember(
      id: 'gm_local_3',
      cohortId: testLocalGroup.id,
      userId: 'local_user_alex',
      role: 'member',
      joinedAt: DateTime.now(),
      profile: UserProfile(id: 'local_user_alex', fullName: 'Alex', createdAt: DateTime.now()),
    );
    final added = await repo.addMembersToCohort(testLocalGroup.id, [newMember]);
    expect(added.isNotEmpty, isTrue);

    final membersAfterAdd = cacheService.getCachedMembers(testLocalGroup.id);
    expect(membersAfterAdd.length, 3);
    expect(membersAfterAdd.any((m) => m.displayName == 'Alex'), isTrue);

    // 3. Remove a member
    final removed = await repo.removeMemberFromCohort(testLocalGroup.id, 'local_user_alex');
    expect(removed, isTrue);

    final membersAfterRemove = cacheService.getCachedMembers(testLocalGroup.id);
    expect(membersAfterRemove.length, 2);
    expect(membersAfterRemove.any((m) => m.userId == 'local_user_alex'), isFalse);
  });
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<Group> initial;
  _MockGroupsNotifier(this.initial);

  @override
  AsyncValue<List<Group>> build() {
    return AsyncValue.data(initial);
  }
}

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
import 'package:fairshare/data/providers/groups_provider.dart';
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

    expect(find.text('Local Outings'), findsOneWidget);
    expect(find.text('No Local Outings Yet'), findsOneWidget);
    expect(find.text('Create Local Outing'), findsOneWidget);
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

    expect(find.text('New Local Outing'), findsOneWidget);
    expect(find.text('Offline on this device · Zero login required'), findsOneWidget);

    // Enter Outing Name
    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Dinner with Friends');
    await tester.pumpAndSettle();

    // Add a participant
    final addParticipantField = find.byType(TextField).at(1);
    await tester.enterText(addParticipantField, 'Rahul');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Verify chips: "Me" (default) and "Rahul"
    expect(find.text('Me'), findsOneWidget);
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
}

class _MockGroupsNotifier extends GroupsNotifier {
  final List<Group> initial;
  _MockGroupsNotifier(this.initial);

  @override
  AsyncValue<List<Group>> build() {
    return AsyncValue.data(initial);
  }
}

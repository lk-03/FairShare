import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/direct_debt.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/utils/currency_formatter.dart';
import 'package:fairshare/data/providers/auth_provider.dart';
import 'package:fairshare/data/providers/expenses_provider.dart';
import 'package:fairshare/features/groups/presentation/widgets/member_profile_sheet.dart';

void main() {
  final testUser = UserProfile(
    id: 'usr_me',
    email: 'me@fairshare.app',
    fullName: 'Alex Vance',
    createdAt: DateTime(2026, 1, 1),
  );

  final testGroup = Group(
    id: 'grp_1',
    name: 'Flat 402',
    description: 'Roommate splits',
    category: 'house',
    currency: 'INR',
    createdBy: 'usr_me',
    inviteCode: 'FLAT402',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final memberBob = GroupMember(
    id: 'gm_bob',
    cohortId: 'grp_1',
    userId: 'usr_bob',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'usr_bob',
      fullName: 'Bob Jones',
      email: 'bob@fairshare.app',
      vpaId: 'bobjones@okaxis',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  testWidgets('MemberProfileSheet displays member profile, mutual debt you owe, and VPA', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final debt = DirectDebt(
      fromUserId: 'usr_me',
      toUserId: 'usr_bob',
      amount: 450.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupDebtsProvider('grp_1').overrideWithValue([debt]),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: MemberProfileSheet(
              cohort: testGroup,
              member: memberBob,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bob Jones'), findsOneWidget);
    expect(find.text('MEMBER · Flat 402'), findsOneWidget);
    expect(find.text('YOU OWE THEM'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(450.0)), findsOneWidget);
    expect(find.text('Settle Up Debt'), findsOneWidget);
    expect(find.text('bobjones@okaxis'), findsOneWidget);
  });

  testWidgets('MemberProfileSheet displays all settled up when debt is zero', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWith(() => _MockCurrentUser(testUser)),
          groupDebtsProvider('grp_1').overrideWithValue([]),
        ],
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: MemberProfileSheet(
              cohort: testGroup,
              member: memberBob,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ALL SETTLED UP'), findsOneWidget);
    expect(find.text('₹0.00'), findsOneWidget);
  });
}

class _MockCurrentUser extends CurrentUserNotifier {
  final UserProfile _user;
  _MockCurrentUser(this._user);

  @override
  UserProfile? build() => _user;
}

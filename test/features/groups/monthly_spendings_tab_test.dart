import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/expense.dart';
import 'package:fairshare/core/models/group.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/features/groups/presentation/widgets/monthly_spendings_tab.dart';

void main() {
  final cohort = Group(
    id: 'grp_1',
    name: 'Flat 402',
    description: 'Roommate splits',
    category: 'house',
    currency: 'INR',
    createdBy: 'usr_1',
    inviteCode: 'FLAT402',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  final member1 = GroupMember(
    id: 'gm_1',
    cohortId: 'grp_1',
    userId: 'usr_1',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'usr_1',
      fullName: 'Alice Smith',
      email: 'alice@test.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final member2 = GroupMember(
    id: 'gm_2',
    cohortId: 'grp_1',
    userId: 'usr_2',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'usr_2',
      fullName: 'Bob Jones',
      email: 'bob@test.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  testWidgets('MonthlySpendingsTab renders empty state when no expenses exist', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: MonthlySpendingsTab(
            cohort: cohort,
            expenses: const [],
            members: [member1, member2],
            currentUserId: 'usr_1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No expenses logged yet'), findsOneWidget);
    expect(find.text('Spendings and category breakdown will appear here once expenses are added.'), findsOneWidget);
  });

  testWidgets('MonthlySpendingsTab renders spending summary, categories and contributions', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final expense1 = Expense(
      id: 'exp_1',
      cohortId: 'grp_1',
      title: 'Groceries',
      category: 'house',
      totalAmount: 1200.0,
      paidByUserId: 'usr_1',
      splits: [
        ExpenseSplit(userId: 'usr_1', amount: 600.0),
        ExpenseSplit(userId: 'usr_2', amount: 600.0),
      ],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final expense2 = Expense(
      id: 'exp_2',
      cohortId: 'grp_1',
      title: 'Dinner Takeout',
      category: 'dining',
      totalAmount: 800.0,
      paidByUserId: 'usr_2',
      splits: [
        ExpenseSplit(userId: 'usr_1', amount: 400.0),
        ExpenseSplit(userId: 'usr_2', amount: 400.0),
      ],
      createdAt: DateTime(2026, 1, 2),
      updatedAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: MonthlySpendingsTab(
            cohort: cohort,
            expenses: [expense1, expense2],
            members: [member1, member2],
            currentUserId: 'usr_1',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify dual-spend hero headers
    expect(find.text('Total Group Spend'), findsOneWidget);
    expect(find.text('Your Personal Share'), findsOneWidget);

    // Verify category breakdown section
    expect(find.text('Category Breakdown'), findsOneWidget);

    // Verify member contribution section
    expect(find.text('Member Contribution Matrix'), findsOneWidget);
    expect(find.text('You'), findsWidgets);
    expect(find.text('Bob Jones'), findsWidgets);
  });
}

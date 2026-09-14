import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/features/expenses/presentation/widgets/adjust_split_sheet.dart';

void main() {
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

  testWidgets('AdjustSplitSheet renders 4 modes and switches between them', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdjustSplitResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AdjustSplitSheet.show(
                  context,
                  members: [member1, member2],
                  totalAmount: 1000.0,
                  initialSplitType: SplitType.equal,
                  initialSplits: const [],
                );
              },
              child: const Text('Open Split Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Split Sheet'));
    await tester.pumpAndSettle();

    // Verify header and 4 tabs
    expect(find.text('Adjust split'), findsOneWidget);
    expect(find.text('Equally'), findsOneWidget);
    expect(find.text('Unequally'), findsOneWidget);
    expect(find.text('Percent'), findsOneWidget);
    expect(find.text('Shares'), findsOneWidget);

    // Default mode is Equally (2 members => ₹ 500.00 each)
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);

    // Switch to Unequally mode
    await tester.tap(find.text('Unequally'));
    await tester.pumpAndSettle();

    // TextFields for exact amounts appear
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Enter 600 for Alice and 400 for Bob
    await tester.enterText(textFields.at(0), '600');
    await tester.enterText(textFields.at(1), '400');
    await tester.pumpAndSettle();

    // Tap confirm check icon
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.splitType, SplitType.exact);
    expect(result!.splits.length, 2);

    final splitAlice = result!.splits.firstWhere((s) => s.userId == 'usr_1');
    final splitBob = result!.splits.firstWhere((s) => s.userId == 'usr_2');
    expect(splitAlice.amount, 600.0);
    expect(splitBob.amount, 400.0);
  });

  testWidgets('AdjustSplitSheet supports Percent mode and computes shares', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdjustSplitResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AdjustSplitSheet.show(
                  context,
                  members: [member1, member2],
                  totalAmount: 1000.0,
                  initialSplitType: SplitType.equal,
                  initialSplits: const [],
                );
              },
              child: const Text('Open Split Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Split Sheet'));
    await tester.pumpAndSettle();

    // Switch to Percent mode
    await tester.tap(find.text('Percent'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Enter 70% for Alice and 30% for Bob
    await tester.enterText(textFields.at(0), '70');
    await tester.enterText(textFields.at(1), '30');
    await tester.pumpAndSettle();

    // Tap confirm
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.splitType, SplitType.percentage);
    expect(result!.splits.length, 2);

    final splitAlice = result!.splits.firstWhere((s) => s.userId == 'usr_1');
    final splitBob = result!.splits.firstWhere((s) => s.userId == 'usr_2');
    expect(splitAlice.amount, 700.0);
    expect(splitBob.amount, 300.0);
  });

  testWidgets('AdjustSplitSheet supports Adjust mode and computes remainder equally', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final member3 = GroupMember(
      id: 'gm_3',
      cohortId: 'grp_1',
      userId: 'usr_3',
      joinedAt: DateTime(2026, 1, 1),
      profile: UserProfile(
        id: 'usr_3',
        fullName: 'Charlie Davis',
        email: 'charlie@test.com',
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    AdjustSplitResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AdjustSplitSheet.show(
                  context,
                  members: [member1, member2, member3],
                  totalAmount: 50.0,
                  initialSplitType: SplitType.equal,
                  initialSplits: const [],
                );
              },
              child: const Text('Open Split Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Split Sheet'));
    await tester.pumpAndSettle();

    // Verify 5 tabs
    expect(find.text('Adjust'), findsOneWidget);

    // Tap Adjust tab
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    // Verify header and description
    expect(find.text('Split by adjustment'), findsOneWidget);
    expect(
      find.text('Enter adjustments to reflect who owes extra; FairShare will distribute the remainder equally.'),
      findsOneWidget,
    );

    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(3));

    // Enter +20 for Alice
    await tester.enterText(textFields.at(0), '20');
    await tester.pumpAndSettle();

    // Verify calculated totals:
    // Total 50, Alice +20, remainder 30 split among 3 => base 10
    // Alice = 30 (10 + 20), Bob = 10 (10 + 0), Charlie = 10 (10 + 0)
    expect(find.text('₹30.00'), findsOneWidget);
    expect(find.text('₹10.00'), findsNWidgets(2));

    // Tap confirm
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.splitType, SplitType.adjustment);
    expect(result!.splits.length, 3);

    final splitAlice = result!.splits.firstWhere((s) => s.userId == 'usr_1');
    final splitBob = result!.splits.firstWhere((s) => s.userId == 'usr_2');
    final splitCharlie = result!.splits.firstWhere((s) => s.userId == 'usr_3');
    expect(splitAlice.amount, 30.0);
    expect(splitAlice.adjustment, 20.0);
    expect(splitBob.amount, 10.0);
    expect(splitCharlie.amount, 10.0);
  });

  testWidgets('AdjustSplitSheet shows warning when adjustments exceed total amount', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    AdjustSplitResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await AdjustSplitSheet.show(
                  context,
                  members: [member1, member2],
                  totalAmount: 50.0,
                  initialSplitType: SplitType.equal,
                  initialSplits: const [],
                );
              },
              child: const Text('Open Split Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Split Sheet'));
    await tester.pumpAndSettle();

    // Tap Adjust tab
    await tester.tap(find.text('Adjust'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);

    // Enter 60 for Alice (exceeds total of 50)
    await tester.enterText(textFields.at(0), '60');
    await tester.pumpAndSettle();

    // Verify footer shows over amount
    expect(find.text('₹10.00 over'), findsOneWidget);

    // Tap check to confirm - should be blocked
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    // Sheet should not be closed and result should still be null
    expect(result, isNull);
    expect(find.text('Adjustments exceed total amount by ₹10.00.'), findsOneWidget);
  });
}

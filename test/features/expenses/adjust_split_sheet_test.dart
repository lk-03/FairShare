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
}

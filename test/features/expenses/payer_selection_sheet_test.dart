import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/features/expenses/presentation/widgets/payer_selection_sheet.dart';

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

  testWidgets('PayerSelectionSheet renders single payer mode and selects a member', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PayerSelectionResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PayerSelectionSheet.show(
                  context,
                  members: [member1, member2],
                  totalAmount: 500.0,
                  initialPaidByUserId: 'usr_1',
                  initialPayers: const [],
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    expect(find.text('Who paid?'), findsOneWidget);
    expect(find.text('Single Person'), findsOneWidget);
    expect(find.text('Multiple People'), findsOneWidget);
    expect(find.text('Alice Smith'), findsOneWidget);
    expect(find.text('Bob Jones'), findsOneWidget);

    // Tap Bob Jones to select Bob as single payer
    await tester.tap(find.text('Bob Jones'));
    await tester.pumpAndSettle();

    // Confirm selection
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.primaryPaidByUserId, 'usr_2');
    expect(result!.payers.length, 1);
    expect(result!.payers.first.userId, 'usr_2');
    expect(result!.payers.first.amount, 500.0);
  });

  testWidgets('PayerSelectionSheet allows custom amounts in Multiple People mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    PayerSelectionResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await PayerSelectionSheet.show(
                  context,
                  members: [member1, member2],
                  totalAmount: 600.0,
                  initialPaidByUserId: 'usr_1',
                  initialPayers: const [],
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();

    // Switch to Multiple People
    await tester.tap(find.text('Multiple People'));
    await tester.pumpAndSettle();

    // Input fields for each member are displayed
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    // Enter 350 for Alice and 250 for Bob
    await tester.enterText(textFields.at(0), '350');
    await tester.enterText(textFields.at(1), '250');
    await tester.pumpAndSettle();

    // Confirm
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.payers.length, 2);

    final payerAlice = result!.payers.firstWhere((p) => p.userId == 'usr_1');
    final payerBob = result!.payers.firstWhere((p) => p.userId == 'usr_2');
    expect(payerAlice.amount, 350.0);
    expect(payerBob.amount, 250.0);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/config/theme/app_theme.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/core/models/receipt_data.dart';
import 'package:fairshare/core/models/split.dart';
import 'package:fairshare/features/expenses/presentation/widgets/itemized_receipt_sheet.dart';

void main() {
  final memberAlice = GroupMember(
    id: 'gm_1',
    cohortId: 'cohort_1',
    userId: 'user_alice',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_alice',
      fullName: 'Alice Walker',
      email: 'alice@test.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final memberBob = GroupMember(
    id: 'gm_2',
    cohortId: 'cohort_1',
    userId: 'user_bob',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_bob',
      fullName: 'Bob Smith',
      email: 'bob@test.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final members = [memberAlice, memberBob];

  testWidgets('ItemizedReceiptSheet displays initial scanner UI when no receipt is scanned', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.buildTheme(brightness: Brightness.dark),
        home: const Scaffold(
          body: ItemizedReceiptSheet(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Scan Receipt'), findsOneWidget);
    expect(find.text('AI Receipt Scanner'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('From Gallery'), findsOneWidget);
    expect(find.textContaining('Zero cloud persistence'), findsOneWidget);
  });

  testWidgets('ItemizedReceiptSheet renders parsed receipt items, member chips, and applies exact itemized splits',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const testReceipt = ParsedReceiptData(
      merchantName: 'Smoke House Deli',
      date: '2026-10-14',
      category: 'dining',
      items: [
        ParsedReceiptItem(name: 'Truffle Pasta', price: 600.0),
        ParsedReceiptItem(name: 'Iced Tea', price: 200.0),
      ],
      subtotal: 800.0,
      tax: 80.0,
      totalAmount: 880.0,
    );

    ReceiptScanResult? returnedResult;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.buildTheme(brightness: Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await ItemizedReceiptSheet.show(
                    ctx,
                    members: members,
                    currentUserId: 'user_alice',
                    initialParsedData: testReceipt,
                  );
                },
                child: const Text('Open Scanner'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to open sheet
    await tester.tap(find.text('Open Scanner'));
    await tester.pumpAndSettle();

    // Verify vendor details
    expect(find.text('Smoke House Deli'), findsOneWidget);
    expect(find.text('₹880.00'), findsWidgets);
    expect(find.text('Truffle Pasta'), findsOneWidget);
    expect(find.text('Iced Tea'), findsOneWidget);

    // Verify member assignment chips
    expect(find.text('Alice'), findsWidgets);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('CALCULATED ITEM SPLITS'), findsOneWidget);

    // Initial state: both items shared equally -> 880 split 2 ways = 440 each
    expect(find.text('₹440.00'), findsWidgets);

    // Tap to apply itemized split
    expect(find.textContaining('Apply Itemized Split'), findsOneWidget);
    await tester.tap(find.textContaining('Apply Itemized Split'));
    await tester.pumpAndSettle();

    expect(returnedResult, isNotNull);
    expect(returnedResult!.splitType, SplitType.exact);
    expect(returnedResult!.splits!.length, 2);

    final aliceSplit = returnedResult!.splits!.firstWhere((s) => s.userId == 'user_alice');
    final bobSplit = returnedResult!.splits!.firstWhere((s) => s.userId == 'user_bob');
    expect(aliceSplit.amount, 440.0);
    expect(bobSplit.amount, 440.0);
    expect(aliceSplit.amount + bobSplit.amount, 880.0);
  });
}

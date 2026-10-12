import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/need_item.dart';
import 'package:fairshare/features/expenses/presentation/widgets/cross_off_cart_sheet.dart';

void main() {
  group('CrossOffCartSheet', () {
    final memberAlice = GroupMember(
      id: 'm1',
      cohortId: 'cohort_1',
      userId: 'user_alice',
      originalCsvName: 'Alice',
      joinedAt: DateTime(2026, 1, 1),
    );

    final memberBob = GroupMember(
      id: 'm2',
      cohortId: 'cohort_1',
      userId: 'user_bob',
      originalCsvName: 'Bob',
      joinedAt: DateTime(2026, 1, 1),
    );

    final needBanana = NeedItem(
      id: 'need_1',
      cohortId: 'cohort_1',
      title: 'Bananas',
      addedByUserId: 'user_alice',
      createdAt: DateTime(2026, 10, 10),
      addedByName: 'Alice',
    );

    final needMilk = NeedItem(
      id: 'need_2',
      cohortId: 'cohort_1',
      title: 'Whole Milk',
      addedByUserId: 'user_bob',
      createdAt: DateTime(2026, 10, 11),
      addedByName: 'Bob',
    );

    testWidgets('renders single item card with author and action buttons', (tester) async {
      Set<String>? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await CrossOffCartSheet.show(
                    context,
                    matchedItems: [needBanana],
                    members: [memberAlice, memberBob],
                    currentUserId: 'user_bob',
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

      expect(find.text('House Cart Match'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
      expect(
        find.textContaining('Alice added this to the group house cart'),
        findsOneWidget,
      );
      expect(find.text('Cross Off & Save'), findsOneWidget);
      expect(find.text('Keep in Cart'), findsOneWidget);

      // Tap "Cross Off & Save"
      await tester.tap(find.text('Cross Off & Save'));
      await tester.pumpAndSettle();

      expect(returnedResult, equals({'need_1'}));
    });

    testWidgets('tapping "Keep in Cart" returns empty set', (tester) async {
      Set<String>? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await CrossOffCartSheet.show(
                    context,
                    matchedItems: [needBanana],
                    members: [memberAlice, memberBob],
                    currentUserId: 'user_bob',
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

      await tester.tap(find.text('Keep in Cart'));
      await tester.pumpAndSettle();

      expect(returnedResult, isEmpty);
    });

    testWidgets('renders multi-item list with checkboxes and handles toggling', (tester) async {
      Set<String>? returnedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  returnedResult = await CrossOffCartSheet.show(
                    context,
                    matchedItems: [needBanana, needMilk],
                    members: [memberAlice, memberBob],
                    currentUserId: 'user_bob',
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

      expect(find.text('Found 2 matching cart items:'), findsOneWidget);
      expect(find.text('Bananas'), findsOneWidget);
      expect(find.text('Whole Milk'), findsOneWidget);
      expect(find.text('Added by Alice'), findsOneWidget);
      expect(find.text('Added by You'), findsOneWidget); // because currentUserId is user_bob

      // Uncheck Bananas
      await tester.tap(find.text('Bananas'));
      await tester.pumpAndSettle();

      // Submit with only Whole Milk checked
      await tester.tap(find.text('Cross Off (1) & Save'));
      await tester.pumpAndSettle();

      expect(returnedResult, equals({'need_2'}));
    });
  });
}

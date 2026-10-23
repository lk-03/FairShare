import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/models/group_member.dart';
import 'package:fairshare/core/models/receipt_data.dart';
import 'package:fairshare/core/models/profile.dart';
import 'package:fairshare/features/receipts/domain/services/receipt_split_calculator.dart';

void main() {
  final memberAlice = GroupMember(
    id: 'gm_1',
    cohortId: 'cohort_1',
    userId: 'user_alice',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_alice',
      fullName: 'Alice',
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
      fullName: 'Bob',
      email: 'bob@test.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final memberCharlie = GroupMember(
    id: 'gm_3',
    cohortId: 'cohort_1',
    userId: 'user_charlie',
    role: 'member',
    joinedAt: DateTime(2026, 1, 1),
    profile: UserProfile(
      id: 'user_charlie',
      fullName: 'Charlie',
      email: 'charlie@test.com',
      createdAt: DateTime(2026, 1, 1),
    ),
  );

  final members = [memberAlice, memberBob, memberCharlie];

  group('ReceiptSplitCalculator', () {
    test('returns empty list when members are empty', () {
      const receipt = ParsedReceiptData(
        merchantName: 'Test Cafe',
        date: '2026-10-14',
        totalAmount: 100.0,
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: [],
        itemAssignments: {},
      );

      expect(splits, isEmpty);
    });

    test('falls back to equal split when items list is empty', () {
      const receipt = ParsedReceiptData(
        merchantName: 'No Items Vendor',
        date: '2026-10-14',
        totalAmount: 100.0,
        items: [],
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: members,
        itemAssignments: {},
      );

      expect(splits.length, 3);
      final sum = splits.fold(0.0, (acc, s) => acc + s.amount);
      expect(sum, 100.0);
      expect(splits[0].amount, 33.34);
      expect(splits[1].amount, 33.33);
      expect(splits[2].amount, 33.33);
    });

    test('splits items by individual assignments with no tax', () {
      const receipt = ParsedReceiptData(
        merchantName: 'Pizzeria',
        date: '2026-10-14',
        items: [
          ParsedReceiptItem(name: 'Pizza Alice', price: 400.0),
          ParsedReceiptItem(name: 'Pasta Bob', price: 300.0),
          ParsedReceiptItem(name: 'Salad Charlie', price: 200.0),
        ],
        subtotal: 900.0,
        tax: 0.0,
        totalAmount: 900.0,
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: members,
        itemAssignments: {
          0: {'user_alice'},
          1: {'user_bob'},
          2: {'user_charlie'},
        },
      );

      expect(splits.firstWhere((s) => s.userId == 'user_alice').amount, 400.0);
      expect(splits.firstWhere((s) => s.userId == 'user_bob').amount, 300.0);
      expect(splits.firstWhere((s) => s.userId == 'user_charlie').amount, 200.0);
      expect(splits.fold(0.0, (acc, s) => acc + s.amount), 900.0);
    });

    test('splits shared item among subset of members', () {
      const receipt = ParsedReceiptData(
        merchantName: 'Brewery',
        date: '2026-10-14',
        items: [
          ParsedReceiptItem(name: 'Nachos (Alice & Bob)', price: 300.0),
          ParsedReceiptItem(name: 'Charlie Solo Beer', price: 200.0),
        ],
        subtotal: 500.0,
        totalAmount: 500.0,
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: members,
        itemAssignments: {
          0: {'user_alice', 'user_bob'},
          1: {'user_charlie'},
        },
      );

      expect(splits.firstWhere((s) => s.userId == 'user_alice').amount, 150.0);
      expect(splits.firstWhere((s) => s.userId == 'user_bob').amount, 150.0);
      expect(splits.firstWhere((s) => s.userId == 'user_charlie').amount, 200.0);
      expect(splits.fold(0.0, (acc, s) => acc + s.amount), 500.0);
    });

    test('distributes tax proportionally based on consumed item subtotal', () {
      // Alice had 600 (60%), Bob had 400 (40%). Total items = 1000.
      // Total receipt = 1100 (100 tax).
      // Alice should get 600 + 60 = 660. Bob gets 400 + 40 = 440. Charlie gets 0.
      const receipt = ParsedReceiptData(
        merchantName: 'Fine Dining',
        date: '2026-10-14',
        items: [
          ParsedReceiptItem(name: 'Steak Alice', price: 600.0),
          ParsedReceiptItem(name: 'Fish Bob', price: 400.0),
        ],
        subtotal: 1000.0,
        tax: 100.0,
        totalAmount: 1100.0,
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: members,
        itemAssignments: {
          0: {'user_alice'},
          1: {'user_bob'},
        },
        taxMode: TaxDistributionMode.proportional,
      );

      expect(splits.firstWhere((s) => s.userId == 'user_alice').amount, 660.0);
      expect(splits.firstWhere((s) => s.userId == 'user_bob').amount, 440.0);
      expect(splits.firstWhere((s) => s.userId == 'user_charlie').amount, 0.0);
      expect(splits.fold(0.0, (acc, s) => acc + s.amount), 1100.0);
    });

    test('distributes tax equally among all members when equal mode is selected', () {
      // Alice had 600, Bob had 400, Charlie had 0. Total items = 1000.
      // Total receipt = 1090 (90 tax).
      // Tax divided equally across all 3 members = 30 each.
      // Alice: 600 + 30 = 630. Bob: 400 + 30 = 430. Charlie: 0 + 30 = 30.
      const receipt = ParsedReceiptData(
        merchantName: 'Fine Dining',
        date: '2026-10-14',
        items: [
          ParsedReceiptItem(name: 'Steak Alice', price: 600.0),
          ParsedReceiptItem(name: 'Fish Bob', price: 400.0),
        ],
        subtotal: 1000.0,
        tax: 90.0,
        totalAmount: 1090.0,
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: members,
        itemAssignments: {
          0: {'user_alice'},
          1: {'user_bob'},
        },
        taxMode: TaxDistributionMode.equal,
      );

      expect(splits.firstWhere((s) => s.userId == 'user_alice').amount, 630.0);
      expect(splits.firstWhere((s) => s.userId == 'user_bob').amount, 430.0);
      expect(splits.firstWhere((s) => s.userId == 'user_charlie').amount, 30.0);
      expect(splits.fold(0.0, (acc, s) => acc + s.amount), 1090.0);
    });

    test('reconciles rounding differences down to the exact penny', () {
      // Receipt of 10.00 split among 3 members equally via default unassigned items
      const receipt = ParsedReceiptData(
        merchantName: 'Corner Store',
        date: '2026-10-14',
        items: [
          ParsedReceiptItem(name: 'Item 1', price: 10.0),
        ],
        subtotal: 10.0,
        totalAmount: 10.0,
      );

      final splits = ReceiptSplitCalculator.calculateSplits(
        parsedData: receipt,
        members: members,
        itemAssignments: {}, // empty means shared by all
      );

      final sum = splits.fold(0.0, (acc, s) => acc + s.amount);
      expect(sum, 10.0);
      expect(splits.map((s) => s.amount), containsAll([3.34, 3.33, 3.33]));
    });
  });
}

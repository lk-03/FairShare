import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/utils/splitwise_csv_parser.dart';

void main() {
  group('SplitwiseCsvParser', () {
    const sampleHeader = 'Date,Description,Category,Cost,Currency,LK,Njj,KATTU PUCHI,keith james (removed)';

    test('parses RFC 4180 CSV tokens with commas and quotes', () {
      const csv = '''Date,Description,Category,Cost,Currency,Alice,Bob
2026-03-15,"Instamart(maggi,syrup,curd,banana)",Groceries,390.00,INR,-195.00,195.00
''';
      final result = SplitwiseCsvParser.parseSplitwiseCsv(csv);
      expect(result.rows.length, 1);
      expect(result.rows.first.description, 'Instamart(maggi,syrup,curd,banana)');
      expect(result.rows.first.cost, 390.00);
      expect(result.rows.first.category, 'house');
      expect(result.rows.first.primaryPayerName, 'Bob');
    });

    test('parses single-payer equal split row accurately', () {
      const csv = '''$sampleHeader
2026-03-09,Fans,General,2800.00,INR,-700.00,2100.00,-700.00,-700.00
''';
      final result = SplitwiseCsvParser.parseSplitwiseCsv(csv);
      expect(result.rows.length, 1);
      final row = result.rows.first;
      expect(row.primaryPayerName, 'Njj');
      expect(row.payments['Njj'], 2800.00);
      expect(row.shares['LK'], 700.00);
      expect(row.shares['Njj'], 700.00);
      expect(row.shares['KATTU PUCHI'], 700.00);
      expect(row.shares['keith james (removed)'], 700.00);
    });

    test('parses multi-payer expense row accurately', () {
      const csv = '''$sampleHeader
2026-03-09,moving fees,General,150.00,INR,50.00,-150.00,50.00,50.00
''';
      final result = SplitwiseCsvParser.parseSplitwiseCsv(csv);
      expect(result.rows.length, 1);
      final row = result.rows.first;
      expect(row.payments['LK'], 50.00);
      expect(row.payments['KATTU PUCHI'], 50.00);
      expect(row.payments['keith james (removed)'], 50.00);
      expect(row.shares['Njj'], 150.00);
    });

    test('parses 2-person subgroup expense row accurately', () {
      const csv = '''$sampleHeader
2026-03-18,poori,Dining out,92.00,INR,46.00,-46.00,0.00,0.00
''';
      final result = SplitwiseCsvParser.parseSplitwiseCsv(csv);
      expect(result.rows.length, 1);
      final row = result.rows.first;
      expect(row.primaryPayerName, 'LK');
      expect(row.payments['LK'], 92.00);
      expect(row.shares['LK'], 46.00);
      expect(row.shares['Njj'], 46.00);
      expect(row.shares.containsKey('KATTU PUCHI'), isFalse);
    });

    test('detects debt settlement payment rows', () {
      const csv = '''$sampleHeader
2026-03-11,keith j. paid Njj,Payment,110.00,INR,0.00,-110.00,0.00,110.00
''';
      final result = SplitwiseCsvParser.parseSplitwiseCsv(csv);
      expect(result.rows.length, 1);
      final row = result.rows.first;
      expect(row.isPayment, isTrue);
      expect(row.primaryPayerName, 'keith james (removed)');
    });

    test('converts parsed row to canonical Expense with ID mapping', () {
      const csv = '''$sampleHeader
2026-03-09,Fans,General,2800.00,INR,-700.00,2100.00,-700.00,-700.00
''';
      final result = SplitwiseCsvParser.parseSplitwiseCsv(csv);
      final mapping = {
        'LK': 'user_lk',
        'Njj': 'user_njj',
        'KATTU PUCHI': 'user_kattu',
        'keith james (removed)': 'user_keith',
      };

      final expense = SplitwiseCsvParser.toExpense(
        row: result.rows.first,
        cohortId: 'cohort_flat',
        memberNameToUserId: mapping,
      );

      expect(expense.cohortId, 'cohort_flat');
      expect(expense.title, 'Fans');
      expect(expense.totalAmount, 2800.00);
      expect(expense.paidByUserId, 'user_njj');
      expect(expense.splits.length, 4);
      expect(expense.splits.firstWhere((s) => s.userId == 'user_lk').amount, 700.00);
    });

    test('cleans member name suffix like (removed)', () {
      expect(SplitwiseCsvParser.cleanMemberName('keith james (removed)'), 'keith james');
      expect(SplitwiseCsvParser.cleanMemberName('  Alice  '), 'Alice');
    });

    test('successfully parses actual .misc/export.csv file without errors', () {
      final file = File('.misc/export.csv');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        final result = SplitwiseCsvParser.parseSplitwiseCsv(content);
        expect(result.memberNames.length, 4);
        expect(result.currency, 'INR');
        expect(result.rows.length, greaterThan(300));
        expect(result.totalCost, greaterThan(10000.0));
      }
    });
  });
}

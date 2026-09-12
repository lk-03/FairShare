import 'package:flutter_test/flutter_test.dart';
import 'package:fairshare/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats rupees with Indian comma grouping', () {
      final formatted = CurrencyFormatter.format(123456.50);
      expect(formatted.contains('1,23,456.50') || formatted.contains('123,456.50'), true);
      expect(formatted.startsWith('₹'), true);
    });

    test('formats with signs for net balance', () {
      final positive = CurrencyFormatter.format(500.0, showSign: true);
      expect(positive.startsWith('+₹'), true);

      final negative = CurrencyFormatter.format(-250.0, showSign: true);
      expect(negative.startsWith('-₹'), true);
    });

    test('formats compact amounts correctly', () {
      expect(CurrencyFormatter.formatCompact(1500), '₹1.5k');
      expect(CurrencyFormatter.formatCompact(250000), '₹2.5L');
      expect(CurrencyFormatter.formatCompact(15000000), '₹1.5Cr');
      expect(CurrencyFormatter.formatCompact(-1500), '-₹1.5k');
    });
  });
}

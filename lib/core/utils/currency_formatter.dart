import 'package:intl/intl.dart';

/// CurrencyFormatter provides standardized Indian Rupee formatting across FairShare
class CurrencyFormatter {
  static final NumberFormat _inrFormatWithDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _inrFormatNoDecimals = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats amount into Indian Rupee format (e.g. "₹1,23,456.50")
  static String format(
    double amount, {
    bool showSign = false,
    bool showDecimals = true,
  }) {
    final absAmount = amount.abs();
    final formatter = showDecimals && (absAmount % 1 != 0)
        ? _inrFormatWithDecimals
        : (showDecimals ? _inrFormatWithDecimals : _inrFormatNoDecimals);

    final formatted = formatter.format(absAmount);

    if (showSign) {
      if (amount > 0.009) {
        return '+$formatted';
      } else if (amount < -0.009) {
        return '-$formatted';
      }
    } else if (amount < -0.009) {
      return '-$formatted';
    }

    return formatted;
  }

  /// Alias for format(amount) standard in Indian Rupee
  static String formatINR(
    double amount, {
    bool showSign = false,
    bool showDecimals = true,
  }) =>
      format(amount, showSign: showSign, showDecimals: showDecimals);

  /// Compact representation for charts or small badges (e.g. "₹12.5k", "₹1.4L")
  static String formatCompact(double amount) {
    final abs = amount.abs();
    final sign = amount < -0.009 ? '-' : '';

    if (abs >= 10000000) {
      return '$sign₹${(abs / 10000000).toStringAsFixed(1)}Cr';
    } else if (abs >= 100000) {
      return '$sign₹${(abs / 100000).toStringAsFixed(1)}L';
    } else if (abs >= 1000) {
      return '$sign₹${(abs / 1000).toStringAsFixed(1)}k';
    }

    return '$sign₹${abs.toStringAsFixed(0)}';
  }
}

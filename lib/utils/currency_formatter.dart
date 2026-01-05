import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static String format(num amount) {
    return _formatter.format(amount);
  }

  static String formatCompact(num amount) {
    if (amount >= 10000000) {
      double value = amount / 10000000;
      return '₹${_formatValue(value)}Cr';
    } else if (amount >= 100000) {
      double value = amount / 100000;
      return '₹${_formatValue(value)}L';
    } else {
      return _formatter.format(amount);
    }
  }

  static String _formatValue(double value) {
    // Show up to 1 decimal place, remove .0
    return value.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
}

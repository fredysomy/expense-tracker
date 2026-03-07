import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _compactFormatter = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String currency(double amount) => _currencyFormatter.format(amount);

  static String currencyCompact(double amount) =>
      _compactFormatter.format(amount);

  static String date(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  static String dateShort(DateTime dt) => DateFormat('dd MMM').format(dt);

  static String monthYear(DateTime dt) => DateFormat('MMMM yyyy').format(dt);

  static String time(DateTime dt) => DateFormat('hh:mm a').format(dt);

  static String relativeDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return date(dt);
  }
}

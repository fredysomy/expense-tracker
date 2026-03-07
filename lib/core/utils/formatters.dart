import 'package:intl/intl.dart';

class Formatters {
  static final _currencyFormatter = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static String currency(double amount) => _currencyFormatter.format(amount);

  static String currencyCompact(double amount) {
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (abs >= 1e7) return '${sign}₹${(abs / 1e7).toStringAsFixed(1)}Cr';
    if (abs >= 1e5) return '${sign}₹${(abs / 1e5).toStringAsFixed(1)}L';
    if (abs >= 1000) return '${sign}₹${(abs / 1000).toStringAsFixed(1)}K';
    return '${sign}₹${abs.toStringAsFixed(0)}';
  }

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

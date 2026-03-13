import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../database/database_helper.dart';

const _kTaskName = 'showDailyReminder';
const _kTaskUniqueName = 'daily_reminder';

/// Runs in a background isolate — must be a top-level function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == _kTaskName) {
      await _showReminderAndReschedule();
    }
    return true;
  });
}

Future<void> _showReminderAndReschedule() async {
  final summary = await _buildDailySummary();

  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));

  await plugin.show(
    42,
    summary.title,
    summary.shortBody,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Daily Reminder',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          summary.fullBody,
          summaryText: 'Daily Summary',
        ),
      ),
    ),
  );

  // Reschedule for the same time tomorrow
  final prefs = await SharedPreferences.getInstance();
  final hour = prefs.getInt('reminder_hour') ?? 21;
  final minute = prefs.getInt('reminder_minute') ?? 0;
  await _scheduleNext(hour, minute);
}

Future<_DailySummary> _buildDailySummary() async {
  try {
    final db = await DatabaseHelper().database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toIso8601String();
    final end = DateTime(now.year, now.month, now.day + 1).toIso8601String();

    // Totals grouped by income / expense
    final totals = await db.rawQuery('''
      SELECT c.type, SUM(t.amount) AS total, COUNT(*) AS cnt
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.date >= ? AND t.date < ?
      GROUP BY c.type
    ''', [start, end]);

    double spent = 0, earned = 0;
    int expenseCount = 0, incomeCount = 0;
    for (final row in totals) {
      if (row['type'] == 'expense') {
        spent = (row['total'] as num).toDouble();
        expenseCount = row['cnt'] as int;
      } else {
        earned = (row['total'] as num).toDouble();
        incomeCount = row['cnt'] as int;
      }
    }

    // Top expense category
    String? topCat;
    double topCatAmount = 0;
    if (spent > 0) {
      final rows = await db.rawQuery('''
        SELECT c.name, SUM(t.amount) AS total
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE c.type = 'expense' AND t.date >= ? AND t.date < ?
        GROUP BY c.id, c.name
        ORDER BY total DESC
        LIMIT 1
      ''', [start, end]);
      if (rows.isNotEmpty) {
        topCat = rows.first['name'] as String;
        topCatAmount = (rows.first['total'] as num).toDouble();
      }
    }

    return _DailySummary(
      spent: spent,
      earned: earned,
      expenseCount: expenseCount,
      incomeCount: incomeCount,
      topCategory: topCat,
      topCategoryAmount: topCatAmount,
    );
  } catch (_) {
    return const _DailySummary(
      spent: 0,
      earned: 0,
      expenseCount: 0,
      incomeCount: 0,
    );
  }
}

String _fmt(double amount) =>
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0)
        .format(amount);

class _DailySummary {
  final double spent;
  final double earned;
  final int expenseCount;
  final int incomeCount;
  final String? topCategory;
  final double topCategoryAmount;

  const _DailySummary({
    required this.spent,
    required this.earned,
    required this.expenseCount,
    required this.incomeCount,
    this.topCategory,
    this.topCategoryAmount = 0,
  });

  bool get hasData => expenseCount + incomeCount > 0;
  int get totalCount => expenseCount + incomeCount;

  String get title => hasData ? 'Daily Spending Summary' : 'Daily Summary';

  String get shortBody {
    if (!hasData) return 'No transactions recorded today.';
    if (spent > 0 && earned > 0) {
      return 'Spent ${_fmt(spent)} · Earned ${_fmt(earned)}';
    }
    if (spent > 0) return 'Spent ${_fmt(spent)} today';
    return 'Earned ${_fmt(earned)} today';
  }

  String get fullBody {
    if (!hasData) {
      return 'No transactions recorded today.\nTap to add your first transaction.';
    }

    final lines = <String>[];

    if (spent > 0) {
      lines.add(
          'Spent ${_fmt(spent)}  ($expenseCount transaction${expenseCount == 1 ? '' : 's'})');
      if (topCategory != null) {
        lines.add('Top: $topCategory  ${_fmt(topCategoryAmount)}');
      }
    }

    if (earned > 0) {
      lines.add(
          'Earned ${_fmt(earned)}  ($incomeCount transaction${incomeCount == 1 ? '' : 's'})');
    }

    if (spent > 0 && earned > 0) {
      final net = earned - spent;
      final sign = net >= 0 ? '+' : '';
      lines.add('Net  $sign${_fmt(net)}');
    }

    return lines.join('\n');
  }
}

// ─────────────────────────────────────────────────────────────────────────────

Future<void> _scheduleNext(int hour, int minute) async {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

  await Workmanager().registerOneOffTask(
    _kTaskUniqueName,
    _kTaskName,
    initialDelay: next.difference(now),
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'daily_reminder',
            'Daily Reminder',
            description: 'Daily transaction summary reminder',
            importance: Importance.high,
          ),
        );

    await Workmanager().initialize(callbackDispatcher);
  }

  static Future<bool> requestNotificationPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? true;
  }

  static Future<bool> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestExactAlarmsPermission() ?? true;
  }

  static Future<void> showTestNotification() async {
    await _plugin.show(
      99,
      'Notification Test',
      'Notifications are working correctly!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  static Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await Workmanager().cancelByUniqueName(_kTaskUniqueName);
    await _scheduleNext(time.hour, time.minute);
  }

  static Future<void> cancelReminder() async {
    await Workmanager().cancelByUniqueName(_kTaskUniqueName);
  }

  static const _batteryChannel =
      MethodChannel('com.fredysomy.money_management/battery');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _batteryChannel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _batteryChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }
}

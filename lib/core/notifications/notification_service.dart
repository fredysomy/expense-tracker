import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

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

/// Called from the background isolate — no Flutter UI available.
Future<void> _showReminderAndReschedule() async {
  // Show the notification
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));
  await plugin.show(
    42,
    'Daily Spending Review',
    "Time to review today's transactions",
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Daily Reminder',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );

  // Reschedule for the same time tomorrow
  final prefs = await SharedPreferences.getInstance();
  final hour = prefs.getInt('reminder_hour') ?? 21;
  final minute = prefs.getInt('reminder_minute') ?? 0;
  await _scheduleNext(hour, minute);
}

/// Schedule the next one-off task at the given hour:minute.
Future<void> _scheduleNext(int hour, int minute) async {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
  final delay = next.difference(now);

  await Workmanager().registerOneOffTask(
    _kTaskUniqueName,
    _kTaskName,
    initialDelay: delay,
    existingWorkPolicy: ExistingWorkPolicy.replace,
    constraints: Constraints(networkType: NetworkType.notRequired),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Initialize flutter_local_notifications
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    // Create the notification channel
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

    // Initialize WorkManager with the background callback
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

  // ── Battery optimization (Samsung fix) ──────────────────────────────────

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

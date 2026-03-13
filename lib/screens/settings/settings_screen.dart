import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/notifications/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 21, minute: 0);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('reminder_enabled') ?? false;
      _time = TimeOfDay(
        hour: prefs.getInt('reminder_hour') ?? 21,
        minute: prefs.getInt('reminder_minute') ?? 0,
      );
      _loading = false;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_enabled) {
        // Step 1: notification permission
        final notifGranted =
            await NotificationService.requestNotificationPermission();
        if (!notifGranted) {
          _showSnack('Notification permission denied. Enable it in app Settings.');
          return;
        }

        // Step 2: exact alarm permission (Android 12+)
        final alarmGranted =
            await NotificationService.requestExactAlarmPermission();
        if (!alarmGranted) {
          _showSnack(
              'Exact alarm permission denied. Go to Settings → Apps → Special app access → Alarms & reminders → enable Money Manager.');
          return;
        }

        // Step 3: battery optimization (Samsung kills alarms without this)
        final ignoringBattery =
            await NotificationService.isIgnoringBatteryOptimizations();
        if (!ignoringBattery) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Allow Background Activity'),
                content: const Text(
                    'To receive notifications reliably, please tap "Allow" on the next screen to disable battery optimization for this app.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Skip')),
                  FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await NotificationService
                          .requestIgnoreBatteryOptimizations();
                    },
                    child: const Text('Allow'),
                  ),
                ],
              ),
            );
          }
        }

        await NotificationService.scheduleDailyReminder(_time);
      } else {
        await NotificationService.cancelReminder();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_enabled', _enabled);
      await prefs.setInt('reminder_hour', _time.hour);
      await prefs.setInt('reminder_minute', _time.minute);

      _showSnack(_enabled
          ? 'Reminder saved for ${_time.format(context)} daily'
          : 'Reminder disabled');
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testNotification() async {
    final granted =
        await NotificationService.requestNotificationPermission();
    if (!granted) {
      _showSnack('Notification permission denied.');
      return;
    }
    await NotificationService.showTestNotification();
    _showSnack('Test notification sent — check your notification shade.');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(
                  'NOTIFICATIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.primary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('Daily Reminder',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text(
                            'Get notified to review your transactions'),
                        value: _enabled,
                        onChanged: (v) => setState(() => _enabled = v),
                      ),
                      if (_enabled) ...[
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16)),
                          ),
                          title: const Text('Reminder Time'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _time.format(context),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                  size: 20,
                                  color: scheme.onSurfaceVariant),
                            ],
                          ),
                          onTap: _pickTime,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Settings'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text('Send Test Notification'),
                ),
              ],
            ),
    );
  }
}

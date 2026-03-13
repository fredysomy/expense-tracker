import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/data/export_import_service.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 21, minute: 0);
  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  bool _importing = false;

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
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_enabled) {
        final notifGranted =
            await NotificationService.requestNotificationPermission();
        if (!notifGranted) {
          _showSnack('Notification permission denied.');
          return;
        }

        final alarmGranted =
            await NotificationService.requestExactAlarmPermission();
        if (!alarmGranted) {
          _showSnack(
              'Go to Settings → Apps → Special app access → Alarms & reminders → enable this app.');
          return;
        }

        final ignoringBattery =
            await NotificationService.isIgnoringBatteryOptimizations();
        if (!ignoringBattery && mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Allow Background Activity'),
              content: const Text(
                  'Tap "Allow" on the next screen to disable battery optimization for reliable notifications.'),
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

        await NotificationService.scheduleDailyReminder(_time);
      } else {
        await NotificationService.cancelReminder();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('reminder_enabled', _enabled);
      await prefs.setInt('reminder_hour', _time.hour);
      await prefs.setInt('reminder_minute', _time.minute);

      if (mounted) {
        _showSnack(_enabled
            ? 'Reminder set for ${_time.format(context)} daily'
            : 'Reminder disabled');
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testNotification() async {
    final granted = await NotificationService.requestNotificationPermission();
    if (!granted) {
      _showSnack('Notification permission denied.');
      return;
    }
    await NotificationService.showTestNotification();
    _showSnack('Test notification sent — check your notification shade.');
  }

  // ── Export ──────────────────────────────────────────────────────────────

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final path = await ExportImportService.exportAndShare();
      _showSnack('Backup saved. To import later, pick the file from:\n$path');
    } catch (e) {
      _showSnack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final preview = await ExportImportService.pickFile();
      if (preview == null) return; // user cancelled

      if (!mounted) return;

      // Show confirmation dialog with record counts
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => _ImportConfirmDialog(preview: preview),
      );

      if (confirmed != true) return;

      await ExportImportService.applyImport(preview);

      // Invalidate all providers so UI refreshes
      ref.invalidate(accountsProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(budgetsProvider);

      _showSnack('Import complete — ${preview.transactions.length} transactions, '
          '${preview.accounts.length} accounts loaded.');
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      _showSnack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
                // ── Notifications ───────────────────────────────────────
                _SectionLabel('NOTIFICATIONS', scheme),
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
                                  bottom: Radius.circular(16))),
                          title: const Text('Reminder Time'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _time.format(context),
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.primary),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right,
                                  size: 20, color: scheme.onSurfaceVariant),
                            ],
                          ),
                          onTap: _pickTime,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Settings'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notifications_outlined, size: 18),
                  label: const Text('Send Test Notification'),
                ),

                // ── Data ────────────────────────────────────────────────
                const SizedBox(height: 28),
                _SectionLabel('DATA', scheme),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(16))),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.upload_outlined,
                              size: 20, color: scheme.onPrimaryContainer),
                        ),
                        title: const Text('Export Data',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text(
                            'Save all accounts, categories, transactions & budgets as JSON'),
                        trailing: _exporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.chevron_right,
                                size: 20, color: scheme.onSurfaceVariant),
                        onTap: _exporting ? null : _export,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16))),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.download_outlined,
                              size: 20, color: scheme.onSecondaryContainer),
                        ),
                        title: const Text('Import Data',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text(
                            'Restore from a previously exported JSON file'),
                        trailing: _importing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.chevron_right,
                                size: 20, color: scheme.onSurfaceVariant),
                        onTap: _importing ? null : _import,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _SectionLabel(this.text, this.scheme);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.primary,
          letterSpacing: 0.8,
        ),
      );
}

class _ImportConfirmDialog extends StatelessWidget {
  final ImportPreview preview;
  const _ImportConfirmDialog({required this.preview});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exportedAt = preview.exportedAt != null
        ? DateTime.tryParse(preview.exportedAt!)
        : null;

    return AlertDialog(
      title: const Text('Import Data'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (exportedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Backup from ${_fmt(exportedAt)}',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ),
          const Text(
            'This will REPLACE all current data with:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          _Row(Icons.account_balance_wallet_outlined,
              '${preview.accounts.length} accounts'),
          _Row(Icons.category_outlined,
              '${preview.categories.length} categories'),
          _Row(Icons.receipt_long_outlined,
              '${preview.transactions.length} transactions'),
          _Row(Icons.track_changes_outlined,
              '${preview.budgets.length} budgets'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current data cannot be recovered after import.',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Replace & Import'),
        ),
      ],
    );
  }

  static String _fmt(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Row(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}

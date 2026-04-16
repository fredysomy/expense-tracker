import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/sms/sms_service.dart';
import '../../core/sms/sms_transaction.dart';
import '../../core/utils/formatters.dart';
import '../../repositories/transaction_repository.dart';
import '../quick_add/quick_add_bottom_sheet.dart';

const _kReviewedKey = 'sms_reviewed_ids';

class SmsReviewScreen extends StatefulWidget {
  const SmsReviewScreen({super.key});

  @override
  State<SmsReviewScreen> createState() => _SmsReviewScreenState();
}

class _SmsReviewScreenState extends State<SmsReviewScreen> {
  _Status _status = _Status.loading;
  List<SmsTransaction> _items = [];
  Set<double> _todayAmounts = {}; // amounts already logged today

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Set<String>> _getReviewedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kReviewedKey)?.toSet() ?? {};
  }

  Future<void> _markReviewed(String smsId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_kReviewedKey)?.toSet() ?? {};
    ids.add(smsId);
    // Keep only IDs from today — prune by storing alongside a date prefix
    // Simple approach: cap the list at 500 to avoid bloat
    final list = ids.toList();
    if (list.length > 500) list.removeRange(0, list.length - 500);
    await prefs.setStringList(_kReviewedKey, list);
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final hasPermission = await SmsService.hasPermission;
      if (!hasPermission) {
        setState(() => _status = _Status.permissionDenied);
        return;
      }

      // Fetch SMS and recent logged transactions in parallel
      const daysBack = 1;
      final now = DateTime.now();
      final rangeStart =
          DateTime(now.year, now.month, now.day - (daysBack - 1));
      final rangeEnd = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));

      final results = await Future.wait([
        SmsService.getTodayTransactions(daysBack: daysBack),
        TransactionRepository().getByDateRange(rangeStart, rangeEnd),
        _getReviewedIds(),
      ]);

      final txns = results[0] as List<SmsTransaction>;
      final logged = results[1] as List;
      final reviewed = results[2] as Set<String>;

      // Build a set of amounts already added today (rounded to 2dp for comparison)
      final todayAmounts = logged
          .map((t) => _round2(t.amount as double))
          .toSet();

      setState(() {
        _items = txns.where((t) => !reviewed.contains(t.smsId)).toList();
        _todayAmounts = todayAmounts;
        _status = _Status.loaded;
      });
    } on SmsPermissionException {
      setState(() => _status = _Status.permissionDenied);
    } catch (_) {
      setState(() => _status = _Status.error);
    }
  }

  static double _round2(double v) => (v * 100).round() / 100;

  bool _isDuplicate(double amount) => _todayAmounts.contains(_round2(amount));

  Future<void> _requestPermission() async {
    final granted = await SmsService.requestPermission();
    if (granted) {
      _load();
    } else {
      final status = await Permission.sms.status;
      if (status.isPermanentlyDenied && mounted) {
        openAppSettings();
      }
    }
  }

  Future<void> _dismiss(SmsTransaction txn) async {
    await _markReviewed(txn.smsId);
    setState(() => _items.removeWhere((t) => t.smsId == txn.smsId));
  }

  Future<void> _accept(SmsTransaction txn) async {
    // Remove from list and persist before opening QuickAdd
    await _markReviewed(txn.smsId);
    setState(() => _items.removeWhere((t) => t.smsId == txn.smsId));
    if (!mounted) return;
    await showQuickAdd(context, initialAmount: txn.amount);
    // After user saves the transaction, refresh today's amounts so remaining
    // cards update their duplicate badges
    if (mounted) {
      const daysBack = 1;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day - (daysBack - 1));
      final end = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1));
      final logged = await TransactionRepository().getByDateRange(start, end);
      setState(() {
        _todayAmounts = logged.map((t) => _round2(t.amount)).toSet();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's SMS Transactions"),
        actions: [
          if (_status == _Status.loaded && _items.isNotEmpty)
            TextButton(
              onPressed: () async {
                for (final t in _items) {
                  await _markReviewed(t.smsId);
                }
                setState(() => _items.clear());
              },
              child: const Text('Dismiss all'),
            ),
        ],
      ),
      body: _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    switch (_status) {
      case _Status.loading:
        return const Center(child: CircularProgressIndicator());

      case _Status.permissionDenied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sms_outlined, size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'SMS Permission Needed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Grant Read SMS permission so the app can find transaction '
                  'messages from your bank or UPI apps.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _requestPermission,
                  icon: const Icon(Icons.security_outlined, size: 18),
                  label: const Text('Grant Permission'),
                ),
              ],
            ),
          ),
        );

      case _Status.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              const Text('Failed to read SMS'),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );

      case _Status.loaded:
        if (_items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_chat_read_outlined,
                    size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  'No transaction SMS today',
                  style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Text(
                  'UPI / bank messages with amounts will appear here.',
                  style: TextStyle(fontSize: 12, color: scheme.outlineVariant),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _SmsCard(
              txn: _items[i],
              isDuplicate: _isDuplicate(_items[i].amount),
              onAccept: () => _accept(_items[i]),
              onDismiss: () => _dismiss(_items[i]),
            ),
          ),
        );
    }
  }
}

enum _Status { loading, permissionDenied, error, loaded }

// ── Individual SMS card ───────────────────────────────────────────────────────

class _SmsCard extends StatelessWidget {
  final SmsTransaction txn;
  final bool isDuplicate;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _SmsCard({
    required this.txn,
    required this.isDuplicate,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amountColor = txn.isDebit ? scheme.error : const Color(0xFF58A8F0);
    final amountPrefix = txn.isDebit ? '- ' : '+ ';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: amount + time
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: amountColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    txn.isDebit
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 20,
                    color: amountColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$amountPrefix${Formatters.currency(txn.amount)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: amountColor,
                        ),
                      ),
                      Row(
                        children: [
                          if (txn.merchant != null)
                            Expanded(
                              child: Text(
                                txn.merchant!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          if (txn.isOtp) ...[
                            if (txn.merchant != null) const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'OTP',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Time
                Text(
                  _timeStr(txn.receivedAt),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // SMS body snippet
            Text(
              txn.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            // Sender
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'From: ${txn.sender}',
                style: TextStyle(
                  fontSize: 10,
                  color: scheme.outlineVariant,
                ),
              ),
            ),
            // Duplicate warning
            if (isDuplicate) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'A transaction with this amount was already logged today',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Transaction'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 16),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _timeStr(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:$m $period';
  }
}

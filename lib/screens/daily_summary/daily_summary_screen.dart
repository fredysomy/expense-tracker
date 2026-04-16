import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';
import '../../core/utils/formatters.dart';
import '../../models/transaction_model.dart';
import '../../repositories/transaction_repository.dart';

class DailySummaryScreen extends StatefulWidget {
  const DailySummaryScreen({super.key});

  @override
  State<DailySummaryScreen> createState() => _DailySummaryScreenState();
}

class _DailySummaryScreenState extends State<DailySummaryScreen> {
  _SummaryData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));

      final db = await DatabaseHelper().database;

      // Totals by type
      final totals = await db.rawQuery('''
        SELECT c.type, SUM(t.amount) AS total, COUNT(*) AS cnt
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE t.date >= ? AND t.date < ?
        GROUP BY c.type
      ''', [start.toIso8601String(), end.toIso8601String()]);

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

      // Top 5 expense categories
      final catRows = await db.rawQuery('''
        SELECT c.name, SUM(t.amount) AS total
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE c.type = 'expense' AND t.date >= ? AND t.date < ?
        GROUP BY c.id, c.name
        ORDER BY total DESC
        LIMIT 5
      ''', [start.toIso8601String(), end.toIso8601String()]);

      // All today's transactions (raw list)
      final txns =
          await TransactionRepository().getByDateRange(start, end);

      setState(() {
        _data = _SummaryData(
          spent: spent,
          earned: earned,
          expenseCount: expenseCount,
          incomeCount: incomeCount,
          topCategories: catRows
              .map((r) => _CatRow(
                    name: r['name'] as String,
                    amount: (r['total'] as num).toDouble(),
                  ))
              .toList(),
          transactions: txns,
          date: now,
        );
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Summary · ${DateFormat('d MMM').format(DateTime.now())}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, size: 20),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(
                  child: Text('Could not load summary',
                      style:
                          TextStyle(color: scheme.onSurfaceVariant)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                    children: [
                      _buildStatsRow(scheme),
                      if (_data!.topCategories.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildCategoryCard(scheme),
                      ],
                      const SizedBox(height: 16),
                      _buildTransactionList(scheme),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsRow(ColorScheme scheme) {
    final d = _data!;
    final net = d.earned - d.spent;
    return Row(
      children: [
        _StatCard(
          label: 'Spent',
          value: Formatters.currency(d.spent),
          count: '${d.expenseCount} txn${d.expenseCount == 1 ? '' : 's'}',
          color: scheme.error,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Earned',
          value: Formatters.currency(d.earned),
          count: '${d.incomeCount} txn${d.incomeCount == 1 ? '' : 's'}',
          color: const Color(0xFF58A8F0),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Net',
          value: (net >= 0 ? '+' : '') + Formatters.currency(net),
          count: '${d.expenseCount + d.incomeCount} total',
          color: net >= 0 ? const Color(0xFF58A8F0) : scheme.error,
        ),
      ],
    );
  }

  Widget _buildCategoryCard(ColorScheme scheme) {
    final cats = _data!.topCategories;
    final maxAmount = cats.first.amount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Categories',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface)),
          const SizedBox(height: 10),
          ...cats.map((cat) {
            final pct = maxAmount > 0 ? cat.amount / maxAmount : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(cat.name,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        Formatters.currency(cat.amount),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: scheme.error.withOpacity(0.1),
                      valueColor:
                          AlwaysStoppedAnimation(scheme.error),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransactionList(ColorScheme scheme) {
    final txns = _data!.transactions;
    if (txns.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            'No transactions logged today',
            style:
                TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Transactions  (${txns.length})',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: txns.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant.withOpacity(0.4)),
            itemBuilder: (_, i) => _TxnRow(txn: txns[i]),
          ),
        ),
      ],
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────

class _SummaryData {
  final double spent, earned;
  final int expenseCount, incomeCount;
  final List<_CatRow> topCategories;
  final List<TransactionModel> transactions;
  final DateTime date;

  _SummaryData({
    required this.spent,
    required this.earned,
    required this.expenseCount,
    required this.incomeCount,
    required this.topCategories,
    required this.transactions,
    required this.date,
  });
}

class _CatRow {
  final String name;
  final double amount;
  _CatRow({required this.name, required this.amount});
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value, count;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(height: 2),
            Text(count,
                style: TextStyle(
                    fontSize: 10, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final TransactionModel txn;
  const _TxnRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // We don't have category here — just show amount & note
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              txn.note ?? 'No note',
              style: TextStyle(
                fontSize: 13,
                color: txn.note != null
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            Formatters.currency(txn.amount),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

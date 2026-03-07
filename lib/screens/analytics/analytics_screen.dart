import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../repositories/transaction_repository.dart';
import '../../core/utils/formatters.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() =>
                      _month = DateTime(_month.year, _month.month - 1, 1)),
                ),
                const SizedBox(width: 8),
                Text(Formatters.monthYear(_month),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final next = DateTime(_month.year, _month.month + 1, 1);
                    if (next.isBefore(DateTime(DateTime.now().year,
                        DateTime.now().month + 1, 1))) {
                      setState(() => _month = next);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        children: [
          // Summary row
          FutureBuilder<List<double>>(
            future: Future.wait([
              repo.getTotalByTypeAndMonth('income', _month.year, _month.month),
              repo.getTotalByTypeAndMonth('expense', _month.year, _month.month),
            ]),
            builder: (ctx, snap) {
              final income = snap.data?[0] ?? 0;
              final expense = snap.data?[1] ?? 0;
              final net = income - expense;
              final scheme = Theme.of(context).colorScheme;
              return Row(
                children: [
                  _StatBox(label: 'Income', value: income, color: const Color(0xFF2E7D32)),
                  Container(width: 1, height: 32, color: scheme.outlineVariant),
                  _StatBox(label: 'Expense', value: expense, color: scheme.error),
                  Container(width: 1, height: 32, color: scheme.outlineVariant),
                  _StatBox(
                      label: 'Net',
                      value: net,
                      color: net >= 0 ? const Color(0xFF2E7D32) : scheme.error),
                ],
              );
            },
          ),
          const Divider(height: 16),
          // Pie chart
          FutureBuilder<Map<String, double>>(
            future: repo.getSpendingByCategory(_month.year, _month.month),
            builder: (ctx, snap) {
              final data = snap.data ?? {};
              if (data.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No expense data',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                );
              }
              return _PieSection(
                data: data,
                touchedIndex: _touchedIndex,
                onTouch: (i) => setState(() => _touchedIndex = i),
              );
            },
          ),
          const Divider(height: 16),
          // Bar chart
          FutureBuilder<List<Map<String, dynamic>>>(
            future: repo.getMonthlyTotals(6),
            builder: (ctx, snap) {
              final data = snap.data ?? [];
              if (data.isEmpty) return const SizedBox.shrink();
              return _BarSection(data: data);
            },
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(Formatters.currencyCompact(value.abs()),
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

const _chartColors = [
  Color(0xFF2196F3), Color(0xFFFF5722), Color(0xFF4CAF50),
  Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFF00BCD4),
  Color(0xFFE91E63), Color(0xFF8BC34A), Color(0xFF795548),
];

class _PieSection extends StatelessWidget {
  final Map<String, double> data;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  const _PieSection(
      {required this.data, required this.touchedIndex, required this.onTouch});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = entries.fold(0.0, (s, e) => s + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Category',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (_, r) => onTouch(
                    r?.touchedSection?.touchedSectionIndex ?? -1),
              ),
              sections: entries.asMap().entries.map((e) {
                final i = e.key;
                final pct = total > 0 ? e.value.value / total * 100 : 0;
                final touched = i == touchedIndex;
                return PieChartSectionData(
                  color: _chartColors[i % _chartColors.length],
                  value: e.value.value,
                  title: touched ? '${pct.toStringAsFixed(1)}%' : '',
                  radius: touched ? 68 : 52,
                  titleStyle: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                );
              }).toList(),
              centerSpaceRadius: 36,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: entries.asMap().entries.map((e) {
            final i = e.key;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: _chartColors[i % _chartColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('${e.value.key} ${Formatters.currencyCompact(e.value.value)}',
                    style: const TextStyle(fontSize: 11)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BarSection extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _BarSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal = data.fold(0.0, (m, d) {
      return [m, d['income'] as double, d['expense'] as double]
          .reduce((a, b) => a > b ? a : b);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('6 Months',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(width: 12),
            _Dot(color: const Color(0xFF2E7D32), label: 'Income'),
            const SizedBox(width: 8),
            _Dot(color: scheme.error, label: 'Expense'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxVal * 1.2 + 1,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                    Formatters.currencyCompact(rod.toY),
                    const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    getTitlesWidget: (val, _) {
                      final i = val.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                      return Text(
                        DateFormat('MMM').format(data[i]['month'] as DateTime),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (val, _) => Text(
                      Formatters.currencyCompact(val),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              barGroups: data.asMap().entries.map((e) {
                final income = e.value['income'] as double;
                final expense = e.value['expense'] as double;
                return BarChartGroupData(
                  x: e.key,
                  barsSpace: 3,
                  barRods: [
                    BarChartRodData(
                      toY: income,
                      color: const Color(0xFF2E7D32).withOpacity(0.8),
                      width: 8,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                    BarChartRodData(
                      toY: expense,
                      color: scheme.error.withOpacity(0.8),
                      width: 8,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

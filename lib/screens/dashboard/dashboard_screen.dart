import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/budget_provider.dart';
import '../../repositories/transaction_repository.dart';
import '../../core/utils/formatters.dart';
import '../../models/account.dart';
import '../../models/budget.dart';
import '../budgets/budgets_screen.dart';
import '../budgets/budget_detail_screen.dart';
import '../accounts/accounts_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final budgets = ref.watch(budgetsProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(budgetsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
          children: [
            // ── Budgets ───────────────────────────────────────────────
            budgets.when(
              data: (bs) {
                if (bs.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(
                      title: 'Budgets',
                      action: 'See all',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const BudgetsScreen()),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Card(
                      child: Column(
                        children: bs
                            .map((b) => _BudgetRow(budget: b))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Accounts ──────────────────────────────────────────────
            _SectionHeader(
              title: 'Accounts',
              action: 'Manage',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ),
            ),
            const SizedBox(height: 8),
            accounts.when(
              data: (accs) {
                if (accs.isEmpty) {
                  return _EmptyHint(
                      'No accounts yet — tap Manage to add one');
                }
                return _Card(child: _AccountsGrid(accounts: accs));
              },
              loading: () => const SizedBox(
                  height: 60, child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),

            // ── Category spending donut ────────────────────────────────
            _SectionHeader(
              title: 'Categories',
              subtitle: Formatters.monthYear(now),
            ),
            const SizedBox(height: 8),
            _Card(
              child: _CategoryDonut(year: now.year, month: now.month),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable card wrapper ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader(
      {required this.title, this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2),
            ),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
          ],
        ),
        const Spacer(),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Row(
              children: [
                Text(action!,
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500)),
                Icon(Icons.chevron_right, size: 16, color: scheme.primary),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Monthly summary ──────────────────────────────────────────────────────────

class _MonthlySummaryCard extends StatelessWidget {
  final int year, month;
  const _MonthlySummaryCard({required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository();
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<List<double>>(
      future: Future.wait([
        repo.getTotalByTypeAndMonth('income', year, month),
        repo.getTotalByTypeAndMonth('expense', year, month),
      ]),
      builder: (ctx, snap) {
        final income = snap.data?[0] ?? 0;
        final expense = snap.data?[1] ?? 0;
        final net = income - expense;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Income',
                  value: Formatters.currencyCompact(income),
                  color: const Color(0xFF4CAF50),
                ),
              ),
              Container(
                  width: 1, height: 36, color: scheme.outlineVariant),
              Expanded(
                child: _StatCell(
                  label: 'Expense',
                  value: Formatters.currencyCompact(expense),
                  color: scheme.error,
                ),
              ),
              Container(
                  width: 1, height: 36, color: scheme.outlineVariant),
              Expanded(
                child: _StatCell(
                  label: 'Net',
                  value: (net >= 0 ? '+' : '') +
                      Formatters.currencyCompact(net.abs()),
                  color: net >= 0 ? const Color(0xFF4CAF50) : scheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCell(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

// ── Budget row with circular ring ────────────────────────────────────────────

const _budgetColors = [
  Color(0xFF7C4DFF),
  Color(0xFF00BCD4),
  Color(0xFF4CAF50),
  Color(0xFFFFB300),
  Color(0xFFFF5722),
  Color(0xFFE91E63),
];

class _BudgetRow extends ConsumerWidget {
  final Budget budget;
  const _BudgetRow({required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(budgetStatsProvider(budget));
    final scheme = Theme.of(context).colorScheme;
    final colorIndex =
        budget.name.codeUnits.fold(0, (a, b) => a + b) % _budgetColors.length;
    final accentColor = _budgetColors[colorIndex];

    return stats.when(
      data: (s) {
        final progressColor = s.isOverBudget
            ? scheme.error
            : s.progress > 0.8
                ? Colors.orange
                : accentColor;
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BudgetDetailScreen(budget: budget))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                // Circular progress ring
                _RingProgress(
                  progress: s.progress,
                  color: progressColor,
                  label: '${(s.progress * 100).toInt()}%',
                ),
                const SizedBox(width: 10),
                // Name + spent/limit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.currencyCompact(s.spent)} of ${Formatters.currencyCompact(budget.limitAmount)}',
                        style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Remaining
                Text(
                  Formatters.currencyCompact(s.remaining.abs()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: s.isOverBudget ? scheme.error : const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 28),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RingProgress extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  const _RingProgress(
      {required this.progress, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
              ),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.track_changes_outlined,
                    size: 14, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// ── Accounts 2-col grid ──────────────────────────────────────────────────────

const _accountColors = [
  Color(0xFF1B8A5A), // green
  Color(0xFF1565C0), // blue
  Color(0xFF6A1B9A), // purple
  Color(0xFFE65100), // orange
  Color(0xFF00838F), // teal
  Color(0xFFC62828), // red
];

class _AccountsGrid extends StatelessWidget {
  final List<Account> accounts;
  const _AccountsGrid({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: accounts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (ctx, i) {
        final acc = accounts[i];
        final colorIndex = i % _accountColors.length;
        final color = _accountColors[colorIndex];
        final isNegative = acc.balance < 0;
        return Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                acc.isCredit
                    ? Icons.credit_card
                    : Icons.account_balance,
                size: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(acc.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    Formatters.currencyCompact(acc.balance),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isNegative ? scheme.error : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Category donut ───────────────────────────────────────────────────────────

const _chartColors = [
  Color(0xFFE53935),
  Color(0xFF43A047),
  Color(0xFF00ACC1),
  Color(0xFFFFB300),
  Color(0xFF8E24AA),
  Color(0xFFFF7043),
  Color(0xFF1E88E5),
  Color(0xFF6D4C41),
];

class _CategoryDonut extends ConsumerStatefulWidget {
  final int year, month;
  const _CategoryDonut({required this.year, required this.month});

  @override
  ConsumerState<_CategoryDonut> createState() => _CategoryDonutState();
}

class _CategoryDonutState extends ConsumerState<_CategoryDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository();
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, double>>(
      future: repo.getSpendingByCategory(widget.year, widget.month),
      builder: (ctx, snap) {
        final data = snap.data ?? {};
        if (data.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('No expenses this month',
                  style: TextStyle(
                      fontSize: 13, color: scheme.onSurfaceVariant)),
            ),
          );
        }
        final entries = data.entries.toList();
        final total =
            entries.fold(0.0, (s, e) => s + e.value);

        return Row(
          children: [
            // Donut chart
            SizedBox(
              width: 130,
              height: 130,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (_, r) => setState(() =>
                        _touched =
                            r?.touchedSection?.touchedSectionIndex ?? -1),
                  ),
                  sections: entries.asMap().entries.map((e) {
                    final i = e.key;
                    final touched = i == _touched;
                    final pct = total > 0 ? e.value.value / total * 100 : 0;
                    return PieChartSectionData(
                      color: _chartColors[i % _chartColors.length],
                      value: e.value.value,
                      title: touched ? '${pct.toStringAsFixed(0)}%' : '',
                      radius: touched ? 52 : 42,
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    );
                  }).toList(),
                  centerSpaceRadius: 14,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Legend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: entries.take(5).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final color = _chartColors[i % _chartColors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.value.key,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          Formatters.currencyCompact(e.value.value),
                          style: TextStyle(
                              fontSize: 14,
                              color: scheme.error,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

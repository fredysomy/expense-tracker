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
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(budgetsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          children: [
            // ── Hero card ──────────────────────────────────────────────
            accounts.when(
              data: (accs) =>
                  _HeroCard(accounts: accs, year: now.year, month: now.month),
              loading: () => const SizedBox(height: 130),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 22),

            // ── Accounts ──────────────────────────────────────────────
            _SectionHeader(
              title: 'Accounts',
              action: 'Manage',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountsScreen()),
              ),
            ),
            const SizedBox(height: 10),
            accounts.when(
              data: (accs) {
                if (accs.isEmpty) {
                  return _EmptyHint('No accounts yet — tap Manage to add one');
                }
                return _AccountScroll(accounts: accs);
              },
              loading: () => const SizedBox(
                  height: 92, child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 22),

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
                    const SizedBox(height: 10),
                    _Card(
                      child: Column(
                        children: bs.map((b) => _BudgetRow(budget: b)).toList(),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Category spending donut ────────────────────────────────
            _SectionHeader(
              title: 'Spending',
              subtitle: Formatters.monthYear(now),
            ),
            const SizedBox(height: 10),
            _Card(child: _CategoryDonut(year: now.year, month: now.month)),
          ],
        ),
      ),
    );
  }
}

// ── Hero card ────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final List<Account> accounts;
  final int year, month;
  const _HeroCard(
      {required this.accounts, required this.year, required this.month});

  @override
  Widget build(BuildContext context) {
    final total = accounts.fold(0.0, (s, a) => s + a.balance);
    final scheme = Theme.of(context).colorScheme;
    final repo = TransactionRepository();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style:
                TextStyle(color: scheme.onPrimary.withOpacity(0.72), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(total),
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: scheme.onPrimary.withOpacity(0.15)),
          const SizedBox(height: 14),
          FutureBuilder<List<double>>(
            future: Future.wait([
              repo.getTotalByTypeAndMonth('income', year, month),
              repo.getTotalByTypeAndMonth('expense', year, month),
            ]),
            builder: (ctx, snap) {
              final income = snap.data?[0] ?? 0;
              final expense = snap.data?[1] ?? 0;
              final net = income - expense;
              final onP = scheme.onPrimary;
              return Row(
                children: [
                  _HeroStat(
                      label: 'Income',
                      value: Formatters.currencyCompact(income),
                      color: onP),
                  Container(width: 1, height: 28, color: onP.withOpacity(0.2)),
                  _HeroStat(
                      label: 'Expense',
                      value: Formatters.currencyCompact(expense),
                      color: onP,
                      center: true),
                  Container(width: 1, height: 28, color: onP.withOpacity(0.2)),
                  _HeroStat(
                    label: 'Net',
                    value: (net >= 0 ? '+' : '') +
                        Formatters.currencyCompact(net),
                    color: onP,
                    end: true,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool center, end;
  const _HeroStat(
      {required this.label,
      required this.value,
      required this.color,
      this.center = false,
      this.end = false});

  @override
  Widget build(BuildContext context) {
    final align = end
        ? CrossAxisAlignment.end
        : center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start;
    return Expanded(
      child: Column(
        crossAxisAlignment: align,
        children: [
          Text(label,
              style: TextStyle(color: color.withOpacity(0.65), fontSize: 11)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

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
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1)),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
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
                        fontSize: 13,
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

// ── Accounts horizontal scroll ───────────────────────────────────────────────

const _accountColors = [
  Color(0xFF1B8A5A),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00838F),
  Color(0xFFC62828),
];

class _AccountScroll extends StatelessWidget {
  final List<Account> accounts;
  const _AccountScroll({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final acc = accounts[i];
          final color = _accountColors[i % _accountColors.length];
          final isNeg = acc.balance < 0;
          return Container(
            width: 148,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  acc.isCredit ? Icons.credit_card : Icons.account_balance,
                  color: Colors.white70,
                  size: 16,
                ),
                const Spacer(),
                Text(
                  acc.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.currencyCompact(acc.balance),
                  style: TextStyle(
                    color: isNeg ? Colors.red[200] : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                _RingProgress(
                  progress: s.progress,
                  color: progressColor,
                  label: '${(s.progress * 100).toInt()}%',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${Formatters.currencyCompact(s.spent)} of ${Formatters.currencyCompact(budget.limitAmount)}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Formatters.currencyCompact(s.remaining.abs()),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: s.isOverBudget
                            ? scheme.error
                            : const Color(0xFF4CAF50),
                      ),
                    ),
                    Text(
                      s.isOverBudget ? 'over' : 'left',
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  ],
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
          width: 44,
          height: 44,
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
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
        final total = entries.fold(0.0, (s, e) => s + e.value);

        return Row(
          children: [
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
                      radius: touched ? 54 : 44,
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
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          Formatters.currencyCompact(e.value.value),
                          style: TextStyle(
                              fontSize: 13,
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

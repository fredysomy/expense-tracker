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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                size: 22, color: scheme.onSurfaceVariant),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          ref.invalidate(budgetsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
          children: [
            // ── Budgets ──────────────────────────────────────────────
            budgets.when(
              data: (bs) {
                if (bs.isEmpty) return const SizedBox.shrink();
                return _Section(
                  title: 'Budgets',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetsScreen()),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      ...bs.map((b) => _BudgetRow(budget: b)),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Accounts ──────────────────────────────────────────────
            accounts.when(
              data: (accs) => _Section(
                title: 'Accounts',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountsScreen()),
                ),
                child: accs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('No accounts yet',
                            style: TextStyle(
                                fontSize: 13,
                                color: scheme.onSurfaceVariant)),
                      )
                    : _AccountsGrid(accounts: accs),
              ),
              loading: () => const SizedBox(
                  height: 60,
                  child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Categories donut ──────────────────────────────────────
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Categories',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    Text(Formatters.monthYear(now),
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SurfaceCard(
              child: _CategoryDonut(year: now.year, month: now.month),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card with header ─────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final VoidCallback? onAction;
  final Widget child;
  const _Section({required this.title, this.onAction, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _SurfaceCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (onAction != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Icon(Icons.chevron_right,
                        size: 22, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _SurfaceCard(
      {required this.child,
      this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ── Budget row ───────────────────────────────────────────────────────────────

const _budgetAccents = [
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
    final accentIdx =
        budget.name.codeUnits.fold(0, (a, b) => a + b) % _budgetAccents.length;
    final accent = _budgetAccents[accentIdx];

    return stats.when(
      data: (s) {
        final ringColor = s.isOverBudget
            ? scheme.error
            : s.progress > 0.8
                ? Colors.orange
                : accent;
        return InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BudgetDetailScreen(budget: budget))),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Ring + icon
                _RingIcon(progress: s.progress, color: ringColor),
                const SizedBox(width: 14),
                // Name + spent/limit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(budget.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        '${Formatters.currency(s.spent)} of ${Formatters.currency(budget.limitAmount)}',
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // Remaining
                Text(
                  Formatters.currency(s.remaining.abs()),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: s.isOverBudget
                        ? scheme.error
                        : const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 44),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RingIcon extends StatelessWidget {
  final double progress;
  final Color color;
  const _RingIcon({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.18),
                valueColor: AlwaysStoppedAnimation(color),
                strokeWidth: 4,
                strokeCap: StrokeCap.round,
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C4DFF).withOpacity(0.85),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.track_changes_outlined,
                    size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Accounts 2-col grid ──────────────────────────────────────────────────────

class _AccountsGrid extends StatelessWidget {
  final List<Account> accounts;
  const _AccountsGrid({required this.accounts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      itemCount: accounts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (ctx, i) {
        final acc = accounts[i];
        final color = _accountColor(acc.type);
        final isNeg = acc.balance < 0;
        return Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_accountIcon(acc.type),
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(acc.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  Text(
                    Formatters.currencyCompact(acc.balance),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isNeg ? scheme.error : scheme.onSurface,
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

  static Color _accountColor(String type) {
    switch (type) {
      case 'cash':
        return const Color(0xFF00897B);
      case 'wallet':
        return const Color(0xFF00897B);
      case 'credit':
        return const Color(0xFF3949AB);
      default:
        return const Color(0xFF1E88E5);
    }
  }

  static IconData _accountIcon(String type) {
    switch (type) {
      case 'credit':
        return Icons.credit_card;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'cash':
        return Icons.money;
      default:
        return Icons.account_balance;
    }
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
                  style:
                      TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
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
                    final pct =
                        total > 0 ? e.value.value / total * 100 : 0;
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/budget.dart';
import '../../models/transaction_model.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../repositories/transaction_repository.dart';
import 'add_budget_screen.dart';

class BudgetDetailScreen extends ConsumerWidget {
  final Budget budget;
  const BudgetDetailScreen({super.key, required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(budgetStatsProvider(budget));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(budget.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => AddBudgetScreen(budget: budget)),
            ),
          ),
        ],
      ),
      body: stats.when(
        data: (s) {
          final progressColor = s.isOverBudget
              ? scheme.error
              : s.progress > 0.8
                  ? Colors.orange
                  : scheme.primary;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Main stats card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_periodLabel(budget.period),
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 13)),
                          _PeriodBadge(period: budget.period),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatChip(
                              label: 'Spent',
                              value: Formatters.currency(s.spent),
                              color: progressColor),
                          _StatChip(
                              label: 'Remaining',
                              value: Formatters.currency(s.remaining),
                              color: Colors.green),
                          _StatChip(
                              label: 'Limit',
                              value: Formatters.currency(budget.limitAmount),
                              color: scheme.primary),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: s.progress,
                        backgroundColor: scheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(progressColor),
                        borderRadius: BorderRadius.circular(6),
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      if (s.isOverBudget)
                        Text(
                          'Over budget by ${Formatters.currency(s.overSpent)}',
                          style: TextStyle(
                              color: scheme.error,
                              fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Pace card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Spending Pace',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _PaceRow(
                              label: 'Optimal daily',
                              value: Formatters.currency(s.dailyOptimal),
                              icon: Icons.track_changes_outlined,
                              color: scheme.primary,
                            ),
                          ),
                          Expanded(
                            child: _PaceRow(
                              label: 'Your daily avg',
                              value: Formatters.currency(s.dailyAverage),
                              icon: s.isOnTrack
                                  ? Icons.check_circle_outline
                                  : Icons.warning_amber_outlined,
                              color:
                                  s.isOnTrack ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            s.isOnTrack
                                ? Icons.trending_down
                                : Icons.trending_up,
                            size: 16,
                            color: s.isOnTrack ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.isOnTrack
                                ? 'On track — Projected: ${Formatters.currency(s.projectedSpend)}'
                                : 'Pace exceeded — Projected: ${Formatters.currency(s.projectedSpend)}',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  s.isOnTrack ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Linked categories
              if (s.categories.isNotEmpty) ...[
                Text('Categories',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: s.categories
                      .map((c) => Chip(
                            avatar:
                                Icon(IconHelper.getIcon(c.icon), size: 14),
                            label: Text(c.name),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              // Linked accounts
              if (s.accounts.isNotEmpty) ...[
                Text('Accounts',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: s.accounts
                      .map((a) => Chip(label: Text(a.name)))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              // Transactions in this budget
              Text('Transactions this period',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _BudgetTransactions(budget: budget),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'daily':
        return 'Daily Budget';
      case 'weekly':
        return 'Weekly Budget';
      default:
        return 'Monthly Budget';
    }
  }
}

class _BudgetTransactions extends ConsumerWidget {
  final Budget budget;
  const _BudgetTransactions({required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final (start, end) = budget.currentPeriodRange;

    return FutureBuilder<List<TransactionModel>>(
      future: TransactionRepository().getByCategoryAndAccountAndDateRange(
        categoryIds: budget.categoryIds,
        accountIds: budget.accountIds,
        start: start,
        end: end,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final txns = snapshot.data!;
        if (txns.isEmpty) {
          return Text('No transactions yet in this period.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant));
        }
        return Column(
          children: txns.map((t) {
            final cat = categories.firstWhere((c) => c.id == t.categoryId,
                orElse: () => Category(
                    id: '', name: 'Unknown', type: 'expense', icon: 'more_horiz'));
            final acc = accounts.firstWhere((a) => a.id == t.accountId,
                orElse: () => Account(
                    id: '',
                    name: 'Unknown',
                    type: 'bank',
                    currency: 'INR',
                    balance: 0,
                    createdAt: DateTime(2000)));
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(IconHelper.getIcon(cat.icon),
                      size: 20, color: Colors.red),
                ),
                title: Text(cat.name),
                subtitle: Text(
                    '${acc.name} · ${Formatters.dateShort(t.date)}'),
                trailing: Text(
                  '-${Formatters.currency(t.amount)}',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _PaceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PaceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant)),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _PeriodBadge extends StatelessWidget {
  final String period;
  const _PeriodBadge({required this.period});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        period[0].toUpperCase() + period.substring(1),
        style: TextStyle(
            fontSize: 12,
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

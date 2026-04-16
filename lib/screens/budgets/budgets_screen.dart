import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/budget_provider.dart';
import '../../models/budget.dart';
import '../../core/utils/formatters.dart';
import 'add_budget_screen.dart';
import 'budget_detail_screen.dart';
import '../categories/categories_screen.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined, size: 18),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddBudgetScreen()),
            ),
          ),
        ],
      ),
      body: budgets.when(
        data: (bs) {
          if (bs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 52, color: scheme.outline),
                  const SizedBox(height: 16),
                  Text('No budgets yet',
                      style: TextStyle(
                          fontSize: 16, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text('Track your spending by category',
                      style: TextStyle(
                          fontSize: 13, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 24),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AddBudgetScreen()),
                    ),
                    child: const Text('Create Budget'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            itemCount: bs.length,
            itemBuilder: (ctx, i) => _BudgetCard(budget: bs[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _BudgetCard extends ConsumerWidget {
  final Budget budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(budgetStatsProvider(budget));
    final scheme = Theme.of(context).colorScheme;

    return stats.when(
      data: (s) {
        final color = s.isOverBudget
            ? scheme.error
            : s.progress > 0.8
                ? Colors.orange
                : scheme.primary;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => BudgetDetailScreen(budget: budget)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(budget.name,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${(s.progress * 100).toInt()}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.progress.clamp(0.0, 1.0),
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.isOverBudget
                          ? 'Over by ${Formatters.currency(s.overSpent)}'
                          : '${Formatters.currency(s.remaining)} remaining',
                      style: TextStyle(
                          fontSize: 12,
                          color: s.isOverBudget
                              ? scheme.error
                              : scheme.onSurfaceVariant),
                    ),
                    Row(
                      children: [
                        Text(
                          '${Formatters.currencyCompact(s.spent)} / ${Formatters.currencyCompact(budget.limitAmount)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: s.isOnTrack
                                ? const Color(0xFF58A8F0).withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.isOnTrack ? 'On track' : 'Behind',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: s.isOnTrack
                                    ? const Color(0xFF58A8F0)
                                    : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: LinearProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

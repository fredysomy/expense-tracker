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
            icon: const Icon(Icons.add, size: 20),
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
                  Icon(Icons.donut_small_outlined, size: 40, color: scheme.outline),
                  const SizedBox(height: 12),
                  Text('No budgets yet',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddBudgetScreen()),
                    ),
                    child: const Text('Create Budget'),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            itemCount: bs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) => _BudgetRow(budget: bs[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  final Budget budget;
  const _BudgetRow({required this.budget});

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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BudgetDetailScreen(budget: budget)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(budget.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      '${Formatters.currencyCompact(s.spent)} / ${Formatters.currencyCompact(budget.limitAmount)}',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: s.progress,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.isOverBudget
                          ? 'Over by ${Formatters.currency(s.overSpent)}'
                          : '${Formatters.currency(s.remaining)} left',
                      style: TextStyle(
                          fontSize: 11,
                          color: s.isOverBudget ? scheme.error : scheme.onSurfaceVariant),
                    ),
                    Text(
                      s.isOnTrack ? 'On track' : 'Pace exceeded',
                      style: TextStyle(
                          fontSize: 11,
                          color: s.isOnTrack ? const Color(0xFF2E7D32) : Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

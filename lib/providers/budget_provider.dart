import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/budget.dart';
import '../models/budget_stats.dart';
import '../repositories/budget_repository.dart';
import 'transaction_provider.dart';

class BudgetsNotifier extends AsyncNotifier<List<Budget>> {
  final _repo = BudgetRepository();

  @override
  Future<List<Budget>> build() => _repo.getAll();

  Future<void> add(Budget budget) async {
    await _repo.insert(budget);
    ref.invalidateSelf();
  }

  Future<void> updateBudget(Budget budget) async {
    await _repo.update(budget);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }
}

final budgetsProvider =
    AsyncNotifierProvider<BudgetsNotifier, List<Budget>>(
  BudgetsNotifier.new,
);

final budgetStatsProvider =
    FutureProvider.family<BudgetStats, Budget>((ref, budget) async {
  // Re-compute when transactions change
  ref.watch(transactionsProvider);
  final repo = BudgetRepository();
  return repo.getStats(budget);
});

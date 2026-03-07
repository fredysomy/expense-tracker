import 'budget.dart';
import 'category.dart';
import 'account.dart';

class BudgetStats {
  final Budget budget;
  final List<Category> categories;
  final List<Account> accounts;
  final double spent;

  BudgetStats({
    required this.budget,
    required this.categories,
    required this.accounts,
    required this.spent,
  });

  double get remaining => (budget.limitAmount - spent).clamp(0, budget.limitAmount);
  double get overSpent => (spent - budget.limitAmount).clamp(0, double.infinity);
  bool get isOverBudget => spent > budget.limitAmount;
  double get progress => (spent / budget.limitAmount).clamp(0.0, 1.0);

  double get dailyOptimal {
    final days = budget.daysInPeriod;
    return days > 0 ? budget.limitAmount / days : 0;
  }

  double get dailyAverage {
    final daysElapsed = budget.daysElapsed;
    return daysElapsed > 0 ? spent / daysElapsed : 0;
  }

  bool get isOnTrack => dailyAverage <= dailyOptimal;

  double get projectedSpend {
    final days = budget.daysInPeriod;
    return dailyAverage * days;
  }
}

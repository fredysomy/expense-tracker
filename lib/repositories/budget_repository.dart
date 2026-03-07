import '../core/database/database_helper.dart';
import '../models/budget.dart';
import '../models/budget_stats.dart';
import '../models/category.dart';
import '../models/account.dart';
import 'transaction_repository.dart';
import 'category_repository.dart';
import 'account_repository.dart';

class BudgetRepository {
  final _db = DatabaseHelper();
  final _txnRepo = TransactionRepository();
  final _catRepo = CategoryRepository();
  final _accRepo = AccountRepository();

  Future<List<Budget>> getAll() async {
    final db = await _db.database;
    final maps =
        await db.query('budgets', orderBy: 'created_at DESC');
    final budgets = <Budget>[];
    for (final map in maps) {
      final budget = Budget.fromMap(map);
      final catIds = await _getCategoryIds(budget.id);
      final accIds = await _getAccountIds(budget.id);
      budgets.add(budget.copyWith(
        categoryIds: catIds,
        accountIds: accIds,
      ));
    }
    return budgets;
  }

  Future<List<String>> _getCategoryIds(String budgetId) async {
    final db = await _db.database;
    final rows = await db.query('budget_categories',
        where: 'budget_id = ?', whereArgs: [budgetId]);
    return rows.map((r) => r['category_id'] as String).toList();
  }

  Future<List<String>> _getAccountIds(String budgetId) async {
    final db = await _db.database;
    final rows = await db.query('budget_accounts',
        where: 'budget_id = ?', whereArgs: [budgetId]);
    return rows.map((r) => r['account_id'] as String).toList();
  }

  Future<void> insert(Budget budget) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('budgets', budget.toMap());
      for (final catId in budget.categoryIds) {
        await txn.insert('budget_categories', {
          'budget_id': budget.id,
          'category_id': catId,
        });
      }
      for (final accId in budget.accountIds) {
        await txn.insert('budget_accounts', {
          'budget_id': budget.id,
          'account_id': accId,
        });
      }
    });
  }

  Future<void> update(Budget budget) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('budgets', budget.toMap(),
          where: 'id = ?', whereArgs: [budget.id]);
      await txn.delete('budget_categories',
          where: 'budget_id = ?', whereArgs: [budget.id]);
      await txn.delete('budget_accounts',
          where: 'budget_id = ?', whereArgs: [budget.id]);
      for (final catId in budget.categoryIds) {
        await txn.insert('budget_categories', {
          'budget_id': budget.id,
          'category_id': catId,
        });
      }
      for (final accId in budget.accountIds) {
        await txn.insert('budget_accounts', {
          'budget_id': budget.id,
          'account_id': accId,
        });
      }
    });
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('budget_categories',
          where: 'budget_id = ?', whereArgs: [id]);
      await txn.delete('budget_accounts',
          where: 'budget_id = ?', whereArgs: [id]);
      await txn.delete('budgets', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<BudgetStats> getStats(Budget budget) async {
    final (start, end) = budget.currentPeriodRange;
    final transactions = await _txnRepo.getByCategoryAndAccountAndDateRange(
      categoryIds: budget.categoryIds,
      accountIds: budget.accountIds,
      start: start,
      end: end,
    );
    final spent = transactions.fold(0.0, (sum, t) => sum + t.amount);

    final categories = <Category>[];
    for (final id in budget.categoryIds) {
      final cat = await _catRepo.getById(id);
      if (cat != null) categories.add(cat);
    }

    final accounts = <Account>[];
    for (final id in budget.accountIds) {
      final acc = await _accRepo.getById(id);
      if (acc != null) accounts.add(acc);
    }

    return BudgetStats(
      budget: budget,
      categories: categories,
      accounts: accounts,
      spent: spent,
    );
  }
}

import '../core/database/database_helper.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';

class TransactionRepository {
  final _db = DatabaseHelper();

  Future<List<TransactionModel>> getAll() async {
    final db = await _db.database;
    final maps =
        await db.query('transactions', orderBy: 'date DESC, created_at DESC');
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getByMonth(int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start, end],
      orderBy: 'date DESC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getByDateRange(
      DateTime start, DateTime end) async {
    final db = await _db.database;
    final maps = await db.query(
      'transactions',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<List<TransactionModel>> getByCategoryAndAccountAndDateRange({
    required List<String> categoryIds,
    required List<String> accountIds,
    required DateTime start,
    required DateTime end,
  }) async {
    if (categoryIds.isEmpty || accountIds.isEmpty) return [];
    final db = await _db.database;
    final catPlaceholders = List.filled(categoryIds.length, '?').join(',');
    final accPlaceholders = List.filled(accountIds.length, '?').join(',');
    final maps = await db.rawQuery(
      '''SELECT * FROM transactions
         WHERE category_id IN ($catPlaceholders)
         AND account_id IN ($accPlaceholders)
         AND date >= ? AND date < ?
         ORDER BY date DESC''',
      [...categoryIds, ...accountIds, start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map(TransactionModel.fromMap).toList();
  }

  Future<void> insert(TransactionModel txn, Category category) async {
    final db = await _db.database;
    await db.transaction((txnDb) async {
      await txnDb.insert('transactions', txn.toMap());
      final accountMaps = await txnDb.query('accounts',
          where: 'id = ?', whereArgs: [txn.accountId]);
      if (accountMaps.isNotEmpty) {
        final currentBalance =
            (accountMaps.first['balance'] as num).toDouble();
        final delta = category.isExpense ? -txn.amount : txn.amount;
        await txnDb.update(
          'accounts',
          {'balance': currentBalance + delta},
          where: 'id = ?',
          whereArgs: [txn.accountId],
        );
      }
    });
  }

  Future<void> delete(TransactionModel txn, Category category) async {
    final db = await _db.database;
    await db.transaction((txnDb) async {
      await txnDb.delete('transactions',
          where: 'id = ?', whereArgs: [txn.id]);
      final accountMaps = await txnDb.query('accounts',
          where: 'id = ?', whereArgs: [txn.accountId]);
      if (accountMaps.isNotEmpty) {
        final currentBalance =
            (accountMaps.first['balance'] as num).toDouble();
        // Reverse the balance change
        final delta = category.isExpense ? txn.amount : -txn.amount;
        await txnDb.update(
          'accounts',
          {'balance': currentBalance + delta},
          where: 'id = ?',
          whereArgs: [txn.accountId],
        );
      }
    });
  }

  Future<double> getTotalByTypeAndMonth(
      String type, int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery('''
      SELECT SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE c.type = ? AND t.date >= ? AND t.date < ?
    ''', [type, start, end]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<Map<String, double>> getSpendingByCategory(
      int year, int month) async {
    final db = await _db.database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery('''
      SELECT c.id, c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE c.type = 'expense' AND t.date >= ? AND t.date < ?
      GROUP BY c.id, c.name
      ORDER BY total DESC
    ''', [start, end]);
    return {
      for (final row in result)
        row['name'] as String: (row['total'] as num).toDouble()
    };
  }

  Future<void> update(
    TransactionModel oldTxn,
    Category oldCategory,
    TransactionModel newTxn,
    Category newCategory,
  ) async {
    final db = await _db.database;
    await db.transaction((txnDb) async {
      // Reverse old balance effect
      final accountMaps = await txnDb.query('accounts',
          where: 'id = ?', whereArgs: [oldTxn.accountId]);
      if (accountMaps.isNotEmpty) {
        double balance = (accountMaps.first['balance'] as num).toDouble();
        balance += oldCategory.isExpense ? oldTxn.amount : -oldTxn.amount;
        await txnDb.update('accounts', {'balance': balance},
            where: 'id = ?', whereArgs: [oldTxn.accountId]);
      }
      // Apply new balance effect (may be different account)
      final newAccountMaps = await txnDb.query('accounts',
          where: 'id = ?', whereArgs: [newTxn.accountId]);
      if (newAccountMaps.isNotEmpty) {
        double balance =
            (newAccountMaps.first['balance'] as num).toDouble();
        balance += newCategory.isExpense ? -newTxn.amount : newTxn.amount;
        await txnDb.update('accounts', {'balance': balance},
            where: 'id = ?', whereArgs: [newTxn.accountId]);
      }
      // Update the transaction row
      await txnDb.update('transactions', newTxn.toMap(),
          where: 'id = ?', whereArgs: [oldTxn.id]);
    });
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals(int months) async {
    final db = await _db.database;
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];
    for (int i = months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final start = month.toIso8601String();
      final end = DateTime(month.year, month.month + 1, 1).toIso8601String();
      final rows = await db.rawQuery('''
        SELECT c.type, SUM(t.amount) as total
        FROM transactions t
        JOIN categories c ON t.category_id = c.id
        WHERE t.date >= ? AND t.date < ?
        GROUP BY c.type
      ''', [start, end]);
      double income = 0, expense = 0;
      for (final row in rows) {
        if (row['type'] == 'income') income = (row['total'] as num).toDouble();
        if (row['type'] == 'expense')
          expense = (row['total'] as num).toDouble();
      }
      result.add({'month': month, 'income': income, 'expense': expense});
    }
    return result;
  }
}

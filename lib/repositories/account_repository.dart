import '../core/database/database_helper.dart';
import '../models/account.dart';

class AccountRepository {
  final _db = DatabaseHelper();

  Future<List<Account>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('accounts', orderBy: 'created_at ASC');
    return maps.map(Account.fromMap).toList();
  }

  Future<Account?> getById(String id) async {
    final db = await _db.database;
    final maps =
        await db.query('accounts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Account.fromMap(maps.first);
  }

  Future<void> insert(Account account) async {
    final db = await _db.database;
    await db.insert('accounts', account.toMap());
  }

  Future<void> update(Account account) async {
    final db = await _db.database;
    await db.update('accounts', account.toMap(),
        where: 'id = ?', whereArgs: [account.id]);
  }

  Future<void> updateBalance(String id, double newBalance) async {
    final db = await _db.database;
    await db.update('accounts', {'balance': newBalance},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('accounts', where: 'id = ?', whereArgs: [id]);
  }
}

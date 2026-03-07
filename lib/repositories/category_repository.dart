import '../core/database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  final _db = DatabaseHelper();

  Future<List<Category>> getAll() async {
    final db = await _db.database;
    final maps = await db.query('categories', orderBy: 'type ASC, parent_id ASC, name ASC');
    return maps.map(Category.fromMap).toList();
  }

  Future<List<Category>> getParentsByType(String type) async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'type = ? AND parent_id IS NULL',
      whereArgs: [type],
      orderBy: 'name ASC',
    );
    return maps.map(Category.fromMap).toList();
  }

  Future<List<Category>> getSubcategories(String parentId) async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'parent_id = ?',
      whereArgs: [parentId],
      orderBy: 'name ASC',
    );
    return maps.map(Category.fromMap).toList();
  }

  Future<bool> hasSubcategories(String parentId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM categories WHERE parent_id = ?',
      [parentId],
    );
    return (result.first['cnt'] as int) > 0;
  }

  Future<Category?> getById(String id) async {
    final db = await _db.database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<void> insert(Category category) async {
    final db = await _db.database;
    await db.insert('categories', category.toMap());
  }

  Future<void> update(Category category) async {
    final db = await _db.database;
    await db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    // Also delete subcategories
    await db.delete('categories', where: 'parent_id = ?', whereArgs: [id]);
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }
}

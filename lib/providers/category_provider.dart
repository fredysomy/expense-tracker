import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../repositories/category_repository.dart';

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  final _repo = CategoryRepository();

  @override
  Future<List<Category>> build() => _repo.getAll();

  Future<void> add(Category category) async {
    await _repo.insert(category);
    ref.invalidateSelf();
  }

  Future<void> updateCategory(Category category) async {
    await _repo.update(category);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);

// Only top-level (parent) categories by type
final expenseParentsProvider = Provider<AsyncValue<List<Category>>>((ref) {
  return ref.watch(categoriesProvider).whenData(
        (cats) => cats.where((c) => c.isExpense && !c.isSubcategory).toList(),
      );
});

final incomeParentsProvider = Provider<AsyncValue<List<Category>>>((ref) {
  return ref.watch(categoriesProvider).whenData(
        (cats) => cats.where((c) => c.isIncome && !c.isSubcategory).toList(),
      );
});

// Subcategories for a given parent
final subcategoriesProvider =
    Provider.family<List<Category>, String>((ref, parentId) {
  final cats = ref.watch(categoriesProvider).value ?? [];
  return cats.where((c) => c.parentId == parentId).toList();
});

// All expense categories (parents + subs)
final expenseCategoriesProvider = Provider<AsyncValue<List<Category>>>((ref) {
  return ref.watch(categoriesProvider).whenData(
        (cats) => cats.where((c) => c.isExpense).toList(),
      );
});

final incomeCategoriesProvider = Provider<AsyncValue<List<Category>>>((ref) {
  return ref.watch(categoriesProvider).whenData(
        (cats) => cats.where((c) => c.isIncome).toList(),
      );
});

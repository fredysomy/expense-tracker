import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/category_provider.dart';
import '../../models/category.dart';
import '../../core/utils/icon_helper.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add, size: 22),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
              ),
            ),
          ],
          bottom: TabBar(
            tabs: const [Tab(text: 'Expense'), Tab(text: 'Income')],
            indicatorColor: scheme.primary,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            dividerColor: Colors.transparent,
          ),
        ),
        body: categories.when(
          data: (cats) => TabBarView(
            children: [
              _CategoryList(
                  categories: cats.where((c) => c.isExpense).toList(),
                  allCategories: cats),
              _CategoryList(
                  categories: cats.where((c) => c.isIncome).toList(),
                  allCategories: cats),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  final List<Category> categories;
  final List<Category> allCategories;
  const _CategoryList(
      {required this.categories, required this.allCategories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    // Separate parents and subs
    final parents = categories.where((c) => !c.isSubcategory).toList();

    if (parents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: scheme.outline),
            const SizedBox(height: 12),
            Text('No categories yet',
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
              ),
              child: const Text('Add Category'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
      itemCount: parents.length,
      itemBuilder: (context, i) {
        final cat = parents[i];
        final subs =
            allCategories.where((c) => c.parentId == cat.id).toList();
        return _CategoryCard(
          cat: cat,
          subs: subs,
          onEdit: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => AddCategoryScreen(category: cat)),
          ),
          onDelete: () => _confirmDelete(context, ref, cat),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${cat.name}"? All subcategories will also be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(categoriesProvider.notifier).remove(cat.id);
    }
  }
}

class _CategoryCard extends StatelessWidget {
  final Category cat;
  final List<Category> subs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CategoryCard(
      {required this.cat,
      required this.subs,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Parent row
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(IconHelper.getIcon(cat.icon),
                  color: scheme.onPrimaryContainer, size: 20),
            ),
            title: Text(cat.name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: subs.isNotEmpty
                ? Text('${subs.length} subcategories',
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant))
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline,
                        size: 18, color: scheme.error),
                  ),
                ),
              ],
            ),
          ),
          // Subcategory chips
          if (subs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: subs.map((sub) {
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AddCategoryScreen(category: sub))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(IconHelper.getIcon(sub.icon),
                              size: 11,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(sub.name,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/category_provider.dart';
import '../../models/category.dart';
import '../../core/utils/icon_helper.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  final Category? category;
  const AddCategoryScreen({super.key, this.category});

  @override
  ConsumerState<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String _type;
  late String _icon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _type = c?.type ?? 'expense';
    _icon = c?.icon ?? 'more_horiz';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.category != null;
    final scheme = Theme.of(context).colorScheme;
    final iconList =
        IconHelper.allIconNames;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Category' : 'New Category')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Text('Type', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'expense',
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward, size: 16)),
                ButtonSegment(
                    value: 'income',
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward, size: 16)),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() {
                  _type = s.first;
                  _icon = 'more_horiz';
                });
              },
            ),
            const SizedBox(height: 16),
            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: iconList.map((iconName) {
                final selected = _icon == iconName;
                return InkWell(
                  onTap: () => setState(() => _icon = iconName),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: scheme.primary, width: 2)
                          : null,
                    ),
                    child: Icon(
                      IconHelper.getIcon(iconName),
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isEdit ? 'Save Changes' : 'Create Category'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final category = Category(
        id: widget.category?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        type: _type,
        icon: _icon,
      );
      if (widget.category != null) {
        await ref.read(categoriesProvider.notifier).updateCategory(category);
      } else {
        await ref.read(categoriesProvider.notifier).add(category);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

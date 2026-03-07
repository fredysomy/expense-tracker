import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/budget_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';

class AddBudgetScreen extends ConsumerStatefulWidget {
  final Budget? budget;
  const AddBudgetScreen({super.key, this.budget});

  @override
  ConsumerState<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends ConsumerState<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _limitCtrl;
  late String _period;
  late DateTime _startDate;
  late Set<String> _selectedCategoryIds;
  late Set<String> _selectedAccountIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _limitCtrl =
        TextEditingController(text: b != null ? b.limitAmount.toString() : '');
    _period = b?.period ?? 'monthly';
    _startDate = b?.startDate ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    _selectedCategoryIds = Set.from(b?.categoryIds ?? []);
    _selectedAccountIds = Set.from(b?.accountIds ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.budget != null;
    final categories = ref.watch(expenseCategoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Budget' : 'New Budget'),
        actions: [
          if (isEdit)
            IconButton(
              icon: Icon(Icons.delete_outline, color: scheme.error),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Budget Name',
                prefixIcon: Icon(Icons.label_outline),
                hintText: 'e.g. Monthly Groceries',
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Limit Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Limit is required';
                final n = double.tryParse(v);
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text('Period', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'daily', label: Text('Daily')),
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_period},
              onSelectionChanged: (s) =>
                  setState(() => _period = s.first),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(Formatters.date(_startDate)),
              subtitle: const Text('Start date'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStartDate,
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Categories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Categories',
                    style: Theme.of(context).textTheme.titleSmall),
                Text('${_selectedCategoryIds.length} selected',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final sel = _selectedCategoryIds.contains(cat.id);
                return FilterChip(
                  avatar: Icon(IconHelper.getIcon(cat.icon), size: 14),
                  label: Text(cat.name),
                  selected: sel,
                  onSelected: (_) {
                    setState(() {
                      if (sel) {
                        _selectedCategoryIds.remove(cat.id);
                      } else {
                        _selectedCategoryIds.add(cat.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Accounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Accounts',
                    style: Theme.of(context).textTheme.titleSmall),
                Text('${_selectedAccountIds.length} selected',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            accounts.isEmpty
                ? Text('No accounts yet. Create one first.',
                    style: TextStyle(color: scheme.error))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: accounts.map((acc) {
                      final sel = _selectedAccountIds.contains(acc.id);
                      return FilterChip(
                        label: Text(acc.name),
                        selected: sel,
                        onSelected: (_) {
                          setState(() {
                            if (sel) {
                              _selectedAccountIds.remove(acc.id);
                            } else {
                              _selectedAccountIds.add(acc.id);
                            }
                          });
                        },
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
                  : Text(isEdit ? 'Save Changes' : 'Create Budget'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }
    if (_selectedAccountIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one account')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final budget = Budget(
        id: widget.budget?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        limitAmount: double.parse(_limitCtrl.text),
        period: _period,
        startDate: _startDate,
        createdAt: widget.budget?.createdAt ?? DateTime.now(),
        categoryIds: _selectedCategoryIds.toList(),
        accountIds: _selectedAccountIds.toList(),
      );
      if (widget.budget != null) {
        await ref.read(budgetsProvider.notifier).updateBudget(budget);
      } else {
        await ref.read(budgetsProvider.notifier).add(budget);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Budget'),
        content: const Text('Are you sure you want to delete this budget?'),
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
      await ref
          .read(budgetsProvider.notifier)
          .remove(widget.budget!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

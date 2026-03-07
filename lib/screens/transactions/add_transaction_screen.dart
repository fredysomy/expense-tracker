import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  /// Pass [transaction] to open in edit mode.
  final TransactionModel? transaction;
  const AddTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState
    extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amountCtrl =
      TextEditingController(text: widget.transaction?.amount.toString() ?? '');
  late final _noteCtrl =
      TextEditingController(text: widget.transaction?.note ?? '');

  late String _txnType;
  Category? _selectedParent;
  Category? _selectedSub;
  Account? _selectedAccount;
  late DateTime _date;
  bool _saving = false;

  bool get _isEdit => widget.transaction != null;

  Category? get _effectiveCategory => _selectedSub ?? _selectedParent;

  @override
  void initState() {
    super.initState();
    _date = widget.transaction?.date ?? DateTime.now();
    _txnType = 'expense'; // will be updated once categories load
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _initFromTransaction(List<Category> allCats, List<Account> accounts) {
    if (!_isEdit) return;
    final txn = widget.transaction!;
    // Find category
    final cat = allCats.firstWhere((c) => c.id == txn.categoryId,
        orElse: () => Category(id: '', name: '', type: 'expense', icon: ''));
    if (cat.id.isEmpty) return;

    final newType = cat.type == 'income' ? 'income' : 'expense';
    Category? parent;
    Category? sub;
    if (cat.isSubcategory) {
      sub = cat;
      parent = allCats.firstWhere((c) => c.id == cat.parentId,
          orElse: () => Category(id: '', name: '', type: '', icon: ''));
      if (parent.id.isEmpty) parent = null;
    } else {
      parent = cat;
    }
    final acc = accounts.firstWhere((a) => a.id == txn.accountId,
        orElse: () =>
            Account(id: '', name: '', type: '', currency: '', balance: 0, createdAt: DateTime(2000)));

    if (_txnType != newType ||
        _selectedParent?.id != parent?.id ||
        _selectedSub?.id != sub?.id ||
        _selectedAccount?.id != acc.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _txnType = newType;
            _selectedParent = parent;
            _selectedSub = sub;
            _selectedAccount = acc.id.isEmpty ? null : acc;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCats = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];

    // Pre-fill fields on first load in edit mode
    if (_isEdit && _selectedParent == null && _selectedAccount == null) {
      _initFromTransaction(allCats, accounts);
    }

    final parents =
        allCats.where((c) => c.type == _txnType && !c.isSubcategory).toList();
    final subs = _selectedParent != null
        ? allCats.where((c) => c.parentId == _selectedParent!.id).toList()
        : <Category>[];

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            // Type toggle
            Row(
              children: [
                _TypeBtn(
                  label: 'Expense',
                  selected: _txnType == 'expense',
                  color: scheme.error,
                  onTap: () => setState(() {
                    _txnType = 'expense';
                    _selectedParent = null;
                    _selectedSub = null;
                  }),
                ),
                const SizedBox(width: 8),
                _TypeBtn(
                  label: 'Income',
                  selected: _txnType == 'income',
                  color: const Color(0xFF2E7D32),
                  onTap: () => setState(() {
                    _txnType = 'income';
                    _selectedParent = null;
                    _selectedSub = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Amount
            TextFormField(
              controller: _amountCtrl,
              autofocus: !_isEdit,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '₹ ',
                prefixStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface),
              ),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter amount';
                if (double.tryParse(v) == null || double.parse(v) <= 0)
                  return 'Invalid';
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Parent categories
            _SectionLabel('Category'),
            const SizedBox(height: 4),
            _ChipRow(
              items: parents,
              selectedId: _selectedParent?.id,
              onSelect: (cat) => setState(() {
                _selectedParent = cat;
                _selectedSub = null;
              }),
            ),
            // Subcategories
            if (subs.isNotEmpty) ...[
              const SizedBox(height: 6),
              _SectionLabel(_selectedParent!.name),
              const SizedBox(height: 4),
              _ChipRow(
                items: subs,
                selectedId: _selectedSub?.id,
                onSelect: (cat) => setState(() => _selectedSub = cat),
              ),
            ],
            const SizedBox(height: 12),
            // Account
            _SectionLabel('Account'),
            const SizedBox(height: 4),
            accounts.isEmpty
                ? Text('No accounts. Add one first.',
                    style: TextStyle(fontSize: 12, color: scheme.error))
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: accounts.map((acc) {
                      final sel = _selectedAccount?.id == acc.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAccount = acc),
                        child: Container(
                          height: 32,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: sel
                                ? scheme.primary
                                : scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            acc.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: sel
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 12),
            // Date
            InkWell(
              onTap: _pickDate,
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(Formatters.date(_date),
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined,
                      size: 12, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_outlined, size: 16),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Update' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_effectiveCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a category')));
      return;
    }
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an account')));
      return;
    }
    setState(() => _saving = true);
    try {
      final newNote =
          _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      if (_isEdit) {
        final oldTxn = widget.transaction!;
        final allCats = ref.read(categoriesProvider).value ?? [];
        final oldCat = allCats.firstWhere((c) => c.id == oldTxn.categoryId,
            orElse: () =>
                Category(id: '', name: '', type: 'expense', icon: ''));
        final newTxn = TransactionModel(
          id: oldTxn.id,
          amount: double.parse(_amountCtrl.text),
          accountId: _selectedAccount!.id,
          categoryId: _effectiveCategory!.id,
          date: _date,
          note: newNote,
          createdAt: oldTxn.createdAt,
        );
        await ref
            .read(transactionsProvider.notifier)
            .editTransaction(oldTxn, oldCat, newTxn, _effectiveCategory!);
      } else {
        final txn = TransactionModel(
          id: const Uuid().v4(),
          amount: double.parse(_amountCtrl.text),
          accountId: _selectedAccount!.id,
          categoryId: _effectiveCategory!.id,
          date: _date,
          note: newNote,
          createdAt: DateTime.now(),
        );
        await ref
            .read(transactionsProvider.notifier)
            .add(txn, _effectiveCategory!);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeBtn(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
              color: selected ? color : Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant));
  }
}

class _ChipRow extends StatelessWidget {
  final List<Category> items;
  final String? selectedId;
  final ValueChanged<Category> onSelect;
  const _ChipRow(
      {required this.items,
      required this.selectedId,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: items.map((cat) {
        final sel = selectedId == cat.id;
        return GestureDetector(
          onTap: () => onSelect(cat),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:
                  sel ? scheme.primaryContainer : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: sel
                      ? scheme.primary
                      : scheme.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(IconHelper.getIcon(cat.icon),
                    size: 13,
                    color: sel
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(cat.name,
                    style: TextStyle(
                        fontSize: 12,
                        color: sel
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

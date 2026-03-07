import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/formatters.dart';

Future<void> showQuickAdd(BuildContext context, {bool closeAppOnSave = false}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _QuickAddSheet(closeAppOnSave: closeAppOnSave),
    ),
  );
}

class _QuickAddSheet extends ConsumerStatefulWidget {
  final bool closeAppOnSave;
  const _QuickAddSheet({this.closeAppOnSave = false});

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  String _amountStr = '0';
  String _txnType = 'expense';
  Category? _selectedParent;
  Category? _selectedSub;
  Account? _selectedAccount;
  String _note = '';
  DateTime _date = DateTime.now();
  bool _saving = false;

  Category? get _effectiveCategory => _selectedSub ?? _selectedParent;

  void _keyPress(String key) {
    setState(() {
      if (key == '⌫') {
        if (_amountStr.length > 1) {
          _amountStr = _amountStr.substring(0, _amountStr.length - 1);
        } else {
          _amountStr = '0';
        }
      } else if (key == '.') {
        if (!_amountStr.contains('.')) _amountStr += '.';
      } else {
        if (_amountStr == '0') {
          _amountStr = key;
        } else {
          if (_amountStr.contains('.')) {
            final parts = _amountStr.split('.');
            if (parts[1].length < 2) _amountStr += key;
          } else {
            _amountStr += key;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allCats = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final parents =
        allCats.where((c) => c.type == _txnType && !c.isSubcategory).toList();
    final subs = _selectedParent != null
        ? allCats.where((c) => c.parentId == _selectedParent!.id).toList()
        : <Category>[];

    final scheme = Theme.of(context).colorScheme;
    final bg = scheme.brightness == Brightness.dark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Type tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: ['Income', 'Expense'].map((t) {
                final val = t.toLowerCase();
                final sel = _txnType == val;
                final color =
                    val == 'expense' ? scheme.error : const Color(0xFF2E7D32);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _txnType = val;
                      _selectedParent = null;
                      _selectedSub = null;
                    }),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? color.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? color : scheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        t,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? color : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Date row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: Text(
                    Formatters.date(_date),
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Account chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: accounts.map((acc) {
                final sel = _selectedAccount?.id == acc.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedAccount = acc),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
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
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Amount display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _amountStr,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    color: _txnType == 'expense'
                        ? scheme.error
                        : const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 8),
                Text('₹',
                    style: TextStyle(
                        fontSize: 24,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w300)),
              ],
            ),
          ),
          // Note field (inline, no keyboard)
          GestureDetector(
            onTap: () async {
              final result = await showDialog<String>(
                context: context,
                builder: (ctx) {
                  final ctrl =
                      TextEditingController(text: _note);
                  return AlertDialog(
                    title: const Text('Add note'),
                    content: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                          hintText: 'Note...'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () =>
                              Navigator.pop(ctx, ctrl.text),
                          child: const Text('OK')),
                    ],
                  );
                },
              );
              if (result != null) setState(() => _note = result);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _note.isEmpty ? 'Add note' : _note,
                style: TextStyle(
                    fontSize: 13,
                    color: _note.isEmpty
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface),
              ),
            ),
          ),
          const Divider(height: 1),
          // Categories
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ...parents.map((cat) {
                  final sel = _selectedParent?.id == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedParent = cat;
                        _selectedSub = null;
                      }),
                      child: _CatPill(cat: cat, selected: sel),
                    ),
                  );
                }),
              ],
            ),
          ),
          if (subs.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: subs.map((cat) {
                  final sel = _selectedSub?.id == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedSub = cat),
                      child: _CatPill(cat: cat, selected: sel, small: true),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          // Numeric keypad
          _Keypad(onKey: _keyPress, onSave: _save, saving: _saving),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter an amount')));
      return;
    }
    if (_effectiveCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a category')));
      return;
    }
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select an account')));
      return;
    }
    setState(() => _saving = true);
    try {
      final txn = TransactionModel(
        id: const Uuid().v4(),
        amount: amount,
        accountId: _selectedAccount!.id,
        categoryId: _effectiveCategory!.id,
        date: _date,
        note: _note.isEmpty ? null : _note,
        createdAt: DateTime.now(),
      );
      await ref
          .read(transactionsProvider.notifier)
          .add(txn, _effectiveCategory!);
      if (mounted) {
        Navigator.of(context).pop();
        if (widget.closeAppOnSave) SystemNavigator.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _CatPill extends StatelessWidget {
  final Category cat;
  final bool selected;
  final bool small;
  const _CatPill(
      {required this.cat, required this.selected, this.small = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 10 : 12, vertical: small ? 4 : 6),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            IconHelper.getIcon(cat.icon),
            size: small ? 12 : 14,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            cat.name,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              color: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onSave;
  final bool saving;
  const _Keypad(
      {required this.onKey, required this.onSave, required this.saving});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      ['7', '8', '9', '⌫'],
      ['4', '5', '6', ''],
      ['1', '2', '3', ''],
      ['.', '0', '', '✓'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: rows.map((row) {
          return Row(
            children: row.map((key) {
              if (key.isEmpty) return const Expanded(child: SizedBox());
              final isAction = key == '✓' || key == '⌫';
              final isSave = key == '✓';
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: GestureDetector(
                    onTap: isSave
                        ? saving
                            ? null
                            : onSave
                        : () => onKey(key),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSave
                            ? scheme.primary
                            : isAction
                                ? scheme.errorContainer
                                : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: isSave && saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary),
                            )
                          : Text(
                              key,
                              style: TextStyle(
                                fontSize: key == '⌫' ? 18 : 20,
                                fontWeight: FontWeight.w500,
                                color: isSave
                                    ? scheme.onPrimary
                                    : isAction
                                        ? scheme.onErrorContainer
                                        : scheme.onSurface,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}

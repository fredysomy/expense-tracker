import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/account_provider.dart';
import '../../models/account.dart';

class AddAccountScreen extends ConsumerStatefulWidget {
  final Account? account;
  const AddAccountScreen({super.key, this.account});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  late String _type;
  late String _currency;
  bool _saving = false;

  final _accountTypes = [
    ('bank', 'Bank Account', Icons.account_balance),
    ('cash', 'Cash', Icons.money),
    ('credit', 'Credit Card', Icons.credit_card),
    ('wallet', 'Wallet', Icons.account_balance_wallet),
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _nameCtrl = TextEditingController(text: a?.name ?? '');
    _balanceCtrl =
        TextEditingController(text: a != null ? a.balance.toString() : '');
    _type = a?.type ?? 'bank';
    _currency = a?.currency ?? 'INR';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.account != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Account' : 'New Account'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            Text('Account Type',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _accountTypes.map((t) {
                final selected = _type == t.$1;
                return ChoiceChip(
                  avatar: Icon(t.$3,
                      size: 16,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : null),
                  label: Text(t.$2),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Initial Balance',
                prefixIcon: Icon(Icons.currency_rupee),
                helperText: 'Enter negative for credit balance',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Balance is required';
                if (double.tryParse(v) == null) return 'Invalid number';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Save Changes' : 'Create Account'),
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
      final account = Account(
        id: widget.account?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        type: _type,
        currency: _currency,
        balance: double.parse(_balanceCtrl.text),
        createdAt: widget.account?.createdAt ?? DateTime.now(),
      );
      if (widget.account != null) {
        await ref.read(accountsProvider.notifier).updateAccount(account);
      } else {
        await ref.read(accountsProvider.notifier).add(account);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

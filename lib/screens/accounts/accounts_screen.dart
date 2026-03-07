import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/account_provider.dart';
import '../../models/account.dart';
import '../../core/utils/formatters.dart';
import 'add_account_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddAccountScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: accounts.when(
        data: (accs) {
          if (accs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined,
                      size: 64, color: scheme.outline),
                  const SizedBox(height: 16),
                  const Text('No accounts yet'),
                  const SizedBox(height: 16),
                  FilledButton.tonal(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AddAccountScreen()),
                    ),
                    child: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: accs.length,
            itemBuilder: (context, i) => _AccountCard(account: accs[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  final Account account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isCredit = account.isCredit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _accountIcon(account.type),
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(account.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_accountTypeLabel(account.type)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              Formatters.currency(account.balance.abs()),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isCredit && account.balance < 0
                    ? scheme.error
                    : scheme.primary,
              ),
            ),
            if (isCredit)
              Text('Credit',
                  style: TextStyle(fontSize: 11, color: scheme.outline)),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => AddAccountScreen(account: account)),
        ),
        onLongPress: () => _confirmDelete(context, ref),
      ),
    );
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'credit':
        return Icons.credit_card;
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'cash':
        return Icons.money;
      default:
        return Icons.account_balance;
    }
  }

  String _accountTypeLabel(String type) {
    switch (type) {
      case 'credit':
        return 'Credit Account';
      case 'wallet':
        return 'Wallet';
      case 'cash':
        return 'Cash';
      default:
        return 'Bank Account';
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content:
            Text('Are you sure you want to delete "${account.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(accountsProvider.notifier).remove(account.id);
    }
  }
}

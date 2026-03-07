import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/transaction_model.dart';
import '../../models/category.dart';
import '../../models/account.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import 'add_transaction_screen.dart';

const _txnPalette = [
  Color(0xFFE53935),
  Color(0xFFFF7043),
  Color(0xFFFFB300),
  Color(0xFF8E24AA),
  Color(0xFF1E88E5),
  Color(0xFF00ACC1),
  Color(0xFF43A047),
  Color(0xFF6D4C41),
];

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String? _filterCategoryId;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];
    final accounts = ref.watch(accountsProvider).value ?? [];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                hintStyle:
                    TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                prefixIcon: Icon(Icons.search,
                    size: 18, color: scheme.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filterCategoryId == null,
                  onTap: () => setState(() => _filterCategoryId = null),
                ),
                const SizedBox(width: 6),
                ...categories
                    .where((c) => !c.isSubcategory)
                    .map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterChip(
                            label: c.name,
                            icon: IconHelper.getIcon(c.icon),
                            selected: _filterCategoryId == c.id,
                            onTap: () => setState(() => _filterCategoryId =
                                _filterCategoryId == c.id ? null : c.id),
                          ),
                        )),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: scheme.outlineVariant.withOpacity(0.4)),
          Expanded(
            child: transactions.when(
              data: (txns) {
                final filtered = _filter(txns, categories, accounts);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 48, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text('No transactions',
                            style:
                                TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return _GroupedList(
                  transactions: filtered,
                  categories: categories,
                  accounts: accounts,
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
            ),
          ),
        ],
      ),
    );
  }

  List<TransactionModel> _filter(
    List<TransactionModel> txns,
    List<Category> cats,
    List<Account> accs,
  ) {
    return txns.where((t) {
      if (_filterCategoryId != null) {
        final cat = cats.firstWhere((c) => c.id == t.categoryId,
            orElse: () =>
                Category(id: '', name: '', type: '', icon: ''));
        if (cat.id != _filterCategoryId &&
            cat.parentId != _filterCategoryId) {
          return false;
        }
      }
      if (_search.isNotEmpty) {
        final cat = cats.firstWhere((c) => c.id == t.categoryId,
            orElse: () =>
                Category(id: '', name: '', type: '', icon: ''));
        final acc = accs.firstWhere((a) => a.id == t.accountId,
            orElse: () => Account(
                id: '',
                name: '',
                type: '',
                currency: '',
                balance: 0,
                createdAt: DateTime(2000)));
        final q = _search.toLowerCase();
        if (!cat.name.toLowerCase().contains(q) &&
            !acc.name.toLowerCase().contains(q) &&
            !(t.note?.toLowerCase().contains(q) ?? false)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label,
      this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: selected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _GroupedList extends ConsumerWidget {
  final List<TransactionModel> transactions;
  final List<Category> categories;
  final List<Account> accounts;

  const _GroupedList(
      {required this.transactions,
      required this.categories,
      required this.accounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<TransactionModel>>{};
    for (final t in transactions) {
      grouped.putIfAbsent(Formatters.relativeDate(t.date), () => []).add(t);
    }
    final scheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: grouped.length,
      itemBuilder: (ctx, i) {
        final dateKey = grouped.keys.elementAt(i);
        final dayTxns = grouped[dateKey]!;
        final dayNet = dayTxns.fold<double>(0, (s, t) {
          final cat = categories.firstWhere((c) => c.id == t.categoryId,
              orElse: () =>
                  Category(id: '', name: '', type: 'expense', icon: ''));
          return s + (cat.isExpense ? -t.amount : t.amount);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateKey,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.3)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: dayNet >= 0
                          ? const Color(0xFF2E7D32).withOpacity(0.1)
                          : scheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (dayNet >= 0 ? '+' : '') +
                          Formatters.currency(dayNet),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dayNet >= 0
                              ? const Color(0xFF2E7D32)
                              : scheme.error),
                    ),
                  ),
                ],
              ),
            ),
            ...dayTxns.map((t) => _TxnRow(
                  txn: t,
                  categories: categories,
                  accounts: accounts,
                )),
            Divider(
                height: 1,
                indent: 72,
                color: scheme.outlineVariant.withOpacity(0.3)),
          ],
        );
      },
    );
  }
}

class _TxnRow extends ConsumerWidget {
  final TransactionModel txn;
  final List<Category> categories;
  final List<Account> accounts;
  const _TxnRow(
      {required this.txn, required this.categories, required this.accounts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cat = categories.firstWhere((c) => c.id == txn.categoryId,
        orElse: () => Category(
            id: '', name: 'Unknown', type: 'expense', icon: 'more_horiz'));
    final acc = accounts.firstWhere((a) => a.id == txn.accountId,
        orElse: () => Account(
            id: '',
            name: '',
            type: 'bank',
            currency: 'INR',
            balance: 0,
            createdAt: DateTime(2000)));
    final isExpense = cat.isExpense;
    final amountColor =
        isExpense ? scheme.error : const Color(0xFF2E7D32);
    final colorIndex =
        cat.name.codeUnits.fold(0, (a, b) => a + b) % _txnPalette.length;
    final iconColor =
        isExpense ? _txnPalette[colorIndex] : const Color(0xFF2E7D32);

    return Dismissible(
      key: Key(txn.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete transaction?'),
          content: Text(
              '${isExpense ? '-' : '+'}${Formatters.currency(txn.amount)} · ${cat.name}'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      ),
      onDismissed: (_) =>
          ref.read(transactionsProvider.notifier).remove(txn, cat),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.error,
        child: Icon(Icons.delete_outline, color: scheme.onError, size: 20),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AddTransactionScreen(transaction: txn),
        )),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(IconHelper.getIcon(cat.icon),
                    size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cat.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      acc.name +
                          (txn.note != null ? '  ·  ${txn.note}' : ''),
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isExpense ? '-' : '+'}${Formatters.currency(txn.amount)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

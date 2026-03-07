import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/category.dart';
import '../repositories/transaction_repository.dart';
import 'account_provider.dart';

class TransactionsNotifier
    extends AsyncNotifier<List<TransactionModel>> {
  final _repo = TransactionRepository();

  @override
  Future<List<TransactionModel>> build() => _repo.getAll();

  Future<void> add(TransactionModel txn, Category category) async {
    await _repo.insert(txn, category);
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
  }

  Future<void> remove(TransactionModel txn, Category category) async {
    await _repo.delete(txn, category);
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
  }

  Future<void> editTransaction(
    TransactionModel oldTxn,
    Category oldCategory,
    TransactionModel newTxn,
    Category newCategory,
  ) async {
    await _repo.update(oldTxn, oldCategory, newTxn, newCategory);
    ref.invalidateSelf();
    ref.invalidate(accountsProvider);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<TransactionModel>>(
  TransactionsNotifier.new,
);

// Selected month for filtering (defaults to current month)
final selectedMonthProvider = StateProvider<DateTime>(
  (ref) => DateTime(DateTime.now().year, DateTime.now().month, 1),
);

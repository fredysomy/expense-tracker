import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';

class AccountsNotifier extends AsyncNotifier<List<Account>> {
  final _repo = AccountRepository();

  @override
  Future<List<Account>> build() => _repo.getAll();

  Future<void> add(Account account) async {
    await _repo.insert(account);
    ref.invalidateSelf();
  }

  Future<void> updateAccount(Account account) async {
    await _repo.update(account);
    ref.invalidateSelf();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

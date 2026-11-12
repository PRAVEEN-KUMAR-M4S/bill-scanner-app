import '../entities/balance.dart';
import '../repositories/balance_repository.dart';

/// Loads the account's balance for the dashboard.
class LoadBalance {
  const LoadBalance(this._repository);

  final BalanceRepository _repository;

  Future<Balance> call() => _repository.load();
}

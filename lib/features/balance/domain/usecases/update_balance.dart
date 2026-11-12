import '../entities/balance.dart';
import '../repositories/balance_repository.dart';

/// Stores the figure the user entered on the card's "Update" sheet.
///
/// The amount is the new base; the repository stamps the save time, so the
/// caller only decides *what* the balance is, never *when* it was written.
class UpdateBalance {
  const UpdateBalance(this._repository);

  final BalanceRepository _repository;

  Future<void> call(double base) => _repository.save(Balance(base: base));
}

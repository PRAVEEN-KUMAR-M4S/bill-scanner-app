import '../entities/balance.dart';
import '../repositories/balance_repository.dart';

/// Saves the figure the user entered on the card's "Update" sheet.
///
/// The amount replaces the stored balance — "I have 5,000" is a statement of
/// fact, and spending is tracked by the bills, not subtracted here. It returns
/// the balance that was actually stored, so the caller never has to read it
/// back with a second request.
class UpdateBalance {
  const UpdateBalance(this._repository);

  final BalanceRepository _repository;

  Future<Balance> call(double base) => _repository.save(Balance(base: base));
}

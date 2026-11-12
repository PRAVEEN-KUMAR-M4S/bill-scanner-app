import '../entities/balance.dart';

/// Reads and writes the account's saved balance.
///
/// The contract says nothing about where the figure lives:
/// `BalanceRepositoryImpl` answers from the SQLite `balances` table through
/// `AppDatabase`, and returns [Balance.defaultBase] on a platform with no
/// local database, so the card still renders. Pages never see this interface —
/// they talk to `BalanceBloc`.
abstract interface class BalanceRepository {
  /// The stored balance, or the first-run value when nothing has been saved.
  Future<Balance> load();

  /// Persists the figure the user entered. The repository stamps the time.
  Future<void> save(Balance balance);
}

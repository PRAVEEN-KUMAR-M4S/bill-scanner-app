import '../entities/balance.dart';

/// Reads and writes the account's balance.
///
/// The contract says nothing about where the figure lives. For a signed-in
/// account `BalanceRepositoryImpl` asks the API (`GET /account`, `PUT
/// /account/balance`) and caches what came back in SQLite so the card still
/// renders offline; a guest is answered from the local `balances` table alone.
/// Pages never see this interface — they talk to `BalanceBloc`.
abstract interface class BalanceRepository {
  /// The current figure: the API's for an account, the stored one for a guest,
  /// or the first-run value when nothing has been saved yet.
  Future<Balance> load();

  /// Replaces the figure. Returns what was actually stored, so the card shows
  /// the server's answer rather than the number that was typed.
  Future<Balance> save(Balance balance);
}

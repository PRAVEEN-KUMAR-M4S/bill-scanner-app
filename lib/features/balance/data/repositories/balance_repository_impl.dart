import '../../../../core/database/app_database.dart';
import '../../domain/entities/balance.dart';
import '../../domain/failures/balance_exception.dart';
import '../../domain/repositories/balance_repository.dart';
import '../datasources/account_remote_datasource.dart';

/// The account's balance: the API while signed in, SQLite as the cache.
///
/// The owner is resolved per call, the same way `BillRepositoryImpl` does it:
/// whoever is signed in when the dashboard opens owns the row, and a guest
/// gets the `'guest'` row rather than an account's figure.
///
/// - Signed in: `GET /account` on load and `PUT /account/balance` on save. The
///   answer is also written to the `balances` table, so losing the connection
///   shows the last figure this device saw instead of an error.
/// - Guest: the local table is the only source, as before.
///
/// Platforms without a sqflite plugin (web, Windows, Linux) get
/// [AppDatabase.open() == null]: there the value lives in memory for the run,
/// which is the same bargain the bills cache makes.
class BalanceRepositoryImpl implements BalanceRepository {
  BalanceRepositoryImpl({
    required AppDatabase? database,
    required String Function() ownerId,
    AccountRemoteDataSource? remote,
    bool Function()? hasSession,
  }) : _database = database,
       _ownerId = ownerId,
       _remote = remote,
       _hasSession = hasSession ?? _neverSignedIn;

  static bool _neverSignedIn() => false;

  final AppDatabase? _database;
  final String Function() _ownerId;
  final AccountRemoteDataSource? _remote;

  /// Read per call, so signing in changes the source without a rebuild.
  final bool Function() _hasSession;

  /// The in-memory value used only when there is no local database.
  Balance _memory = const Balance(base: Balance.defaultBase);

  @override
  Future<Balance> load() async {
    final AccountRemoteDataSource? remote = _remote;
    if (remote != null && _hasSession()) {
      try {
        final Balance balance = await remote.fetch();
        await _write(balance);
        return balance;
      } on BalanceException catch (exception) {
        // Offline is the one failure the cache can answer; anything else (an
        // expired session, a broken response) belongs in front of the user.
        if (!exception.offline) rethrow;
      }
    }

    return _stored();
  }

  @override
  Future<Balance> save(Balance balance) async {
    final AccountRemoteDataSource? remote = _remote;
    if (remote != null && _hasSession()) {
      final Balance stored = await remote.setBalance(balance.base);
      await _write(stored);
      return stored;
    }

    final Balance stored = balance.copyWith(updatedAt: DateTime.now());
    await _write(stored);
    return stored;
  }

  Future<Balance> _stored() async {
    final AppDatabase? database = _database;
    if (database == null) return _memory;

    final List<Map<String, Object?>> rows = await database.readBalance(
      _ownerId(),
    );
    if (rows.isEmpty) return const Balance(base: Balance.defaultBase);

    final Map<String, Object?> row = rows.first;
    final String? savedAt = row['updated_at'] as String?;
    return Balance(
      base: (row['base_balance'] as num?)?.toDouble() ?? Balance.defaultBase,
      updatedAt: savedAt == null ? null : DateTime.tryParse(savedAt),
    );
  }

  /// Keeps the figure the card last showed, for the next offline open.
  Future<void> _write(Balance balance) async {
    final Balance row = balance.copyWith(updatedAt: DateTime.now());
    final AppDatabase? database = _database;
    if (database == null) {
      _memory = row;
      return;
    }

    await database.writeBalance(
      _ownerId(),
      base: row.base,
      updatedAt: row.updatedAt ?? DateTime.now(),
    );
  }
}

import '../../../../core/database/app_database.dart';
import '../../domain/entities/balance.dart';
import '../../domain/repositories/balance_repository.dart';

/// Stores the balance in the app's SQLite database, one row per account.
///
/// The owner is resolved per call, the same way `BillRepositoryImpl` does it:
/// whoever is signed in when the dashboard opens owns the row, and a guest
/// gets the `'guest'` row rather than an account's figure.
///
/// Platforms without a sqflite plugin (web, Windows, Linux) get
/// [AppDatabase.open() == null]. There the value lives in memory for the run —
/// the card still works, it just does not survive a restart, which is the same
/// bargain the bills cache makes.
class BalanceRepositoryImpl implements BalanceRepository {
  BalanceRepositoryImpl({
    required AppDatabase? database,
    required String Function() ownerId,
  }) : _database = database,
       _ownerId = ownerId;

  final AppDatabase? _database;
  final String Function() _ownerId;

  /// The in-memory value used only when there is no local database.
  Balance _memory = const Balance(base: Balance.defaultBase);

  @override
  Future<Balance> load() async {
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

  @override
  Future<void> save(Balance balance) async {
    final DateTime now = DateTime.now();
    final AppDatabase? database = _database;
    if (database == null) {
      _memory = balance.copyWith(updatedAt: now);
      return;
    }

    await database.writeBalance(_ownerId(), base: balance.base, updatedAt: now);
  }
}

import 'package:bill_scanner/core/database/app_database.dart';
import 'package:bill_scanner/features/balance/data/repositories/balance_repository_impl.dart';
import 'package:bill_scanner/features/balance/domain/entities/balance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;

  setUp(() async {
    database = (await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: inMemoryDatabasePath,
    ))!;
  });

  tearDown(() => database.close());

  BalanceRepositoryImpl repository({String owner = '7'}) {
    return BalanceRepositoryImpl(database: database, ownerId: () => owner);
  }

  test(
    'an account that never set a balance gets the first-run value',
    () async {
      final Balance loaded = await repository().load();

      expect(loaded.base, Balance.defaultBase);
      expect(loaded.updatedAt, isNull);
    },
  );

  test('a saved figure round-trips through the balances table', () async {
    await repository().save(const Balance(base: 42500));
    final Balance loaded = await repository().load();

    expect(loaded.base, 42500);
    expect(loaded.updatedAt, isNotNull);

    // Proof it is in SQLite, not just in a field of the object.
    final List<Map<String, Object?>> rows = await database.readBalance('7');
    expect(rows, hasLength(1));
    expect((rows.first['base_balance'] as num).toDouble(), 42500);
    expect(rows.first['owner_id'], '7');
  });

  test('saving twice replaces the row instead of duplicating it', () async {
    final BalanceRepositoryImpl repo = repository();

    await repo.save(const Balance(base: 1000));
    await repo.save(const Balance(base: 2500));

    expect((await repo.load()).base, 2500);
    expect(await database.readBalance('7'), hasLength(1));
  });

  test("one account's balance is never another account's", () async {
    await repository(owner: '7').save(const Balance(base: 999));

    expect((await repository(owner: '7').load()).base, 999);
    expect((await repository(owner: 'guest').load()).base, Balance.defaultBase);
    expect(await database.readBalance('guest'), isEmpty);
  });

  test('without a database the figure still holds for the session', () async {
    final BalanceRepositoryImpl repo = BalanceRepositoryImpl(
      database: null,
      ownerId: () => 'guest',
    );

    expect((await repo.load()).base, Balance.defaultBase);

    await repo.save(const Balance(base: 750));

    expect((await repo.load()).base, 750);
    expect((await repo.load()).updatedAt, isNotNull);
  });

  test('a database from version 1 gains the balances table', () async {
    final String path = p.join(
      await databaseFactoryFfi.getDatabasesPath(),
      'v1_bill_scan.db',
    );
    await databaseFactoryFfi.deleteDatabase(path);
    addTearDown(() => databaseFactoryFfi.deleteDatabase(path));

    // Freeze the first release's schema exactly as it shipped, so the test
    // opens a real version-1 file rather than an invented one. The connection
    // is closed afterwards: sqflite caches open files per path, and a second
    // open of a still-cached handle skips the version callbacks.
    final Database v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
CREATE TABLE bills (
  id TEXT PRIMARY KEY NOT NULL,
  owner_id TEXT NOT NULL,
  merchant TEXT NOT NULL,
  bill_date TEXT NOT NULL,
  total REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'INR',
  category TEXT NOT NULL,
  icon TEXT,
  notes TEXT,
  round_off REAL,
  sync_status TEXT NOT NULL CHECK (sync_status IN ('synced', 'pending')),
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)''');
          await db.execute('''
CREATE TABLE bill_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  quantity INTEGER,
  FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
)''');
        },
      ),
    );
    await v1.close();

    final AppDatabase? upgraded = await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: path,
    );
    expect(upgraded, isNotNull);

    // The migration created the table and left it empty…
    expect(await upgraded!.readBalance('7'), isEmpty);
    // …and the new statements work against the migrated file.
    await upgraded.writeBalance(
      '7',
      base: 30000,
      updatedAt: DateTime(2026, 10, 26, 9),
    );
    expect(await upgraded.readBalance('7'), hasLength(1));

    await upgraded.close();
  });
}

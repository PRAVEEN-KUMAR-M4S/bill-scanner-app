import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// One bill and its line items, shaped for the `bills` and `bill_items` tables.
///
/// Rows are plain maps on purpose: the database service never imports a
/// feature entity. `BillRowMapper` in the bills data layer turns a `Bill` into
/// these maps and back, so a column rename touches two files.
typedef BillRows = ({
  Map<String, Object?> bill,
  List<Map<String, Object?>> items,
});

/// The app's on-device SQLite database: the offline cache behind the bills list
/// and the queue of bills waiting to be uploaded.
///
/// This is the only file in the app that speaks SQL. `docs/SQL_GUIDE.md`
/// explains every statement below in the order the app runs it — §4 the schema,
/// §5 the reads, §6 the writes, §7 transactions, §8 indexes — and the section is
/// named on each constant. Read the two together.
///
/// The feature layer never sees a table name: it hands over [BillRows] and gets
/// rows back. Two rules keep the statements safe:
/// - every value is bound as a `?` argument, never stitched into the statement,
///   so a merchant called `O'Brien` cannot break a query;
/// - dates are stored as ISO `yyyy-MM-dd` text, which sorts correctly with a
///   plain `ORDER BY`.
final class AppDatabase {
  AppDatabase._(this._database, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// File name inside the platform's databases directory.
  static const String fileName = 'bill_scan.db';

  /// Bump this whenever the constants below change the schema, and add a
  /// matching step in [_upgrade]. See `docs/SQL_GUIDE.md` §9.
  static const int schemaVersion = 1;

  /// Mirrors `BillSyncState.synced`; the storage name is what the CHECK
  /// constraint in the schema accepts.
  static const String _synced = 'synced';

  /// Mirrors `BillSyncState.pending`.
  static const String _pending = 'pending';

  final Database _database;
  final DateTime Function() _now;

  /// The open connection, for the schema test and for running your own queries
  /// while following `docs/SQL_GUIDE.md` §10.
  Database get raw => _database;

  /// Whether this build has a working sqflite plugin.
  ///
  /// Android, iOS and macOS ship it; web, Windows and Linux do not.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Opens (and on first launch creates) the database.
  ///
  /// Returns `null` where the platform has no sqflite plugin, so the app runs
  /// without a local cache instead of failing to start.
  ///
  /// [factory], [filePath] and [now] exist for tests: pass `databaseFactoryFfi`
  /// with `inMemoryDatabasePath` for a throw-away database that has the real
  /// schema, and a fixed clock to order the queue deterministically.
  static Future<AppDatabase?> open({
    DatabaseFactory? factory,
    String? filePath,
    DateTime Function()? now,
  }) async {
    // Touch the plugin only on a platform that has it: `databaseFactory`
    // itself throws when sqflite was never initialised.
    if (factory == null && !isSupported) return null;

    final DatabaseFactory opener = factory ?? databaseFactory;
    final String location =
        filePath ?? p.join(await opener.getDatabasesPath(), fileName);

    final Database database = await opener.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _configure,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );

    return AppDatabase._(database, now: now);
  }

  /// Runs on every connection, before any table is touched.
  ///
  /// SQLite ignores foreign keys unless this pragma is on *for the connection*,
  /// so without it `ON DELETE CASCADE` would silently do nothing.
  static Future<void> _configure(Database database) {
    return database.execute(_enableForeignKeys);
  }

  /// Runs exactly once, on a fresh install.
  ///
  /// Never edit this after a release: existing installs do not run it again.
  /// Schema changes belong in [_upgrade].
  static Future<void> _create(Database database, int version) async {
    final Batch batch = database.batch();
    batch.execute(_createBillsTable);
    batch.execute(_createBillItemsTable);
    batch.execute(_indexBillsOwnerDate);
    batch.execute(_indexBillsOwnerSync);
    batch.execute(_indexBillItemsBill);
    await batch.commit(noResult: true);
  }

  /// Migrations for installs that already have a database.
  ///
  /// Version 1 is the first release, so there is nothing to migrate yet. When
  /// [schemaVersion] becomes 2, bump it and add the step here:
  ///
  /// ```dart
  /// if (oldVersion < 2) {
  ///   await database.execute('ALTER TABLE bills ADD COLUMN ...');
  /// }
  /// ```
  ///
  /// The steps run in order, so a phone on version 1 that jumps to 3 runs both
  /// the `< 2` and the `< 3` steps.
  static Future<void> _upgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    // Intentionally empty until the first schema change.
  }

  Future<void> close() => _database.close();

  // ---------------------------------------------------------------------------
  // Reading — `docs/SQL_GUIDE.md` §5
  // ---------------------------------------------------------------------------

  /// Every cached bill for [ownerId], newest first.
  ///
  /// [ownerId] is the account id, or `'guest'`; it is what stops one account's
  /// cache from showing up under another's.
  Future<List<Map<String, Object?>>> readBills(String ownerId) {
    return _database.rawQuery(_selectBillsForOwner, <Object?>[ownerId]);
  }

  /// Only the rows waiting to be sent, oldest first so the queue is FIFO.
  Future<List<Map<String, Object?>>> readPendingBills(String ownerId) {
    return _database.rawQuery(_selectPendingBillsForOwner, <Object?>[
      ownerId,
      _pending,
    ]);
  }

  /// The line items of those bills, in printed order.
  ///
  /// One join returns the items of every bill at once — the alternative is a
  /// query per bill, the classic N+1 problem described in §5.2. The caller
  /// groups the rows by `bill_id`.
  Future<List<Map<String, Object?>>> readItems(
    String ownerId, {
    bool pendingOnly = false,
  }) {
    return _database.rawQuery(
      pendingOnly ? _selectPendingItemsForOwner : _selectItemsForOwner,
      <Object?>[ownerId, if (pendingOnly) _pending],
    );
  }

  /// True when [ownerId] already owns at least one row; used once per guest
  /// installation to decide whether the demo bill should be seeded (§5.5).
  Future<bool> hasBills(String ownerId) async {
    final List<Map<String, Object?>> rows = await _database.rawQuery(
      _countBillsForOwner,
      <Object?>[ownerId],
    );
    return ((rows.first['bill_count'] as num?)?.toInt() ?? 0) > 0;
  }

  // ---------------------------------------------------------------------------
  // Writing — `docs/SQL_GUIDE.md` §6
  // ---------------------------------------------------------------------------

  /// Inserts or replaces one bill and its items in a single transaction, so a
  /// cache read never sees a bill without its lines (§6.1, §6.2, §7).
  Future<void> saveBill(String ownerId, BillRows rows) async {
    await _database.transaction((Transaction txn) async {
      await _write(txn, ownerId, rows, syncStatus: rows.bill['sync_status']);
    });
  }

  /// Replaces the server-owned rows after `GET /bills`, keeping the queue.
  ///
  /// Only `synced` rows are deleted; a bill saved while offline must survive
  /// the refresh, otherwise it would vanish the moment the connection came
  /// back (§6.4). Everything written here is stored as [BillSyncState.synced]
  /// because the server already has it.
  Future<void> replaceServerBills(String ownerId, List<BillRows> rows) async {
    await _database.transaction((Transaction txn) async {
      await txn.rawDelete(_deleteSyncedBillsForOwner, <Object?>[
        ownerId,
        _synced,
      ]);
      for (final BillRows bill in rows) {
        await _write(txn, ownerId, bill, syncStatus: _synced);
      }
    });
  }

  /// Swaps a queued bill for the version the server returned, so its local id
  /// becomes the real id and it stops being pending (§6.5).
  ///
  /// Deleting the queued row also removes its items, through the foreign key
  /// with `ON DELETE CASCADE`.
  Future<void> promotePending(
    String ownerId, {
    required String localId,
    required BillRows rows,
  }) async {
    await _database.transaction((Transaction txn) async {
      await txn.rawDelete(_deleteBillById, <Object?>[localId, ownerId]);
      await _write(txn, ownerId, rows, syncStatus: _synced);
    });
  }

  /// Writes one bill and its items. Callers provide the transaction.
  ///
  /// Storage bookkeeping (`owner_id`, the timestamps and the sync status the
  /// caller asks for) is added here; the business columns come from the mapper.
  Future<void> _write(
    DatabaseExecutor executor,
    String ownerId,
    BillRows rows, {
    Object? syncStatus,
  }) async {
    final String timestamp = _now().toIso8601String();
    final String id = rows.bill['id']! as String;

    await executor.insert(_billsTable, <String, Object?>{
      ...rows.bill,
      'owner_id': ownerId,
      'sync_status': syncStatus ?? rows.bill['sync_status'] ?? _synced,
      'created_at': timestamp,
      'updated_at': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // REPLACE deleted the old row (and, with foreign keys on, its items), but
    // the explicit delete keeps the behaviour clear and independent of the
    // pragma.
    await executor.rawDelete(_deleteItemsForBill, <Object?>[id]);

    for (final Map<String, Object?> item in rows.items) {
      await executor.insert(_itemsTable, item);
    }
  }

  // ---------------------------------------------------------------------------
  // Schema — `docs/SQL_GUIDE.md` §4
  // ---------------------------------------------------------------------------

  static const String _billsTable = 'bills';
  static const String _itemsTable = 'bill_items';

  /// One row per bill. `sync_status` is constrained to the two states the app
  /// knows, so a typo cannot create a third one.
  static const String _createBillsTable = '''
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
)''';

  /// One row per printed line. The foreign key makes deleting a bill delete its
  /// items in the same statement.
  static const String _createBillItemsTable = '''
CREATE TABLE bill_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bill_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  name TEXT NOT NULL,
  amount REAL NOT NULL,
  quantity INTEGER,
  FOREIGN KEY (bill_id) REFERENCES bills (id) ON DELETE CASCADE
)''';

  /// Covers the list read: filter by owner, then order by date.
  static const String _indexBillsOwnerDate = '''
CREATE INDEX idx_bills_owner_date
ON bills (owner_id, bill_date DESC)''';

  /// Covers the upload queue: only pending rows for one owner.
  static const String _indexBillsOwnerSync = '''
CREATE INDEX idx_bills_owner_sync
ON bills (owner_id, sync_status)''';

  /// Covers the items join and keeps printed order per bill.
  static const String _indexBillItemsBill = '''
CREATE INDEX idx_bill_items_bill
ON bill_items (bill_id, position)''';

  /// SQLite disables foreign keys by default for backwards compatibility.
  static const String _enableForeignKeys = 'PRAGMA foreign_keys = ON';

  // ---------------------------------------------------------------------------
  // Statements — `docs/SQL_GUIDE.md` §5 and §6
  // ---------------------------------------------------------------------------

  static const String _selectBillsForOwner = '''
SELECT id, owner_id, merchant, bill_date, total, currency, category,
       icon, notes, round_off, sync_status, created_at, updated_at
FROM bills
WHERE owner_id = ?
ORDER BY bill_date DESC, created_at DESC''';

  static const String _selectPendingBillsForOwner = '''
SELECT id, owner_id, merchant, bill_date, total, currency, category,
       icon, notes, round_off, sync_status, created_at, updated_at
FROM bills
WHERE owner_id = ? AND sync_status = ?
ORDER BY created_at ASC''';

  static const String _selectItemsForOwner = '''
SELECT i.bill_id, i.name, i.amount, i.quantity, i.position
FROM bill_items AS i
INNER JOIN bills AS b ON b.id = i.bill_id
WHERE b.owner_id = ?
ORDER BY i.bill_id, i.position''';

  static const String _selectPendingItemsForOwner = '''
SELECT i.bill_id, i.name, i.amount, i.quantity, i.position
FROM bill_items AS i
INNER JOIN bills AS b ON b.id = i.bill_id
WHERE b.owner_id = ? AND b.sync_status = ?
ORDER BY i.bill_id, i.position''';

  static const String _countBillsForOwner = '''
SELECT COUNT(*) AS bill_count
FROM bills
WHERE owner_id = ?''';

  static const String _deleteItemsForBill =
      'DELETE FROM bill_items WHERE bill_id = ?';

  static const String _deleteBillById =
      'DELETE FROM bills WHERE id = ? AND owner_id = ?';

  static const String _deleteSyncedBillsForOwner = '''
DELETE FROM bills
WHERE owner_id = ? AND sync_status = ?''';
}

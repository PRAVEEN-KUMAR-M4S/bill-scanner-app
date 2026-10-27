import '../../../../core/database/app_database.dart';
import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_extraction.dart';
import '../../domain/entities/bill_item.dart';
import '../../domain/entities/bill_sync_state.dart';
import '../../domain/entities/bills_snapshot.dart';
import '../../domain/failures/bill_failure.dart';
import '../../domain/repositories/bill_repository.dart';
import '../datasources/bill_remote_datasource.dart';
import '../models/bill_row_mapper.dart';

/// The app's only bill repository: the API, the offline cache and the guest's
/// device store behind the [BillRepository] contract.
///
/// The session is read at call time through [hasSession], so signing in or out
/// changes behaviour without rebuilding the graph.
///
/// **Signed in.** A read pushes the upload queue, fetches `GET /bills`,
/// rewrites the cached server rows and answers from the cache. When the
/// connection is down it skips the network and answers with
/// [BillsSource.cache]. A save goes to the server; if it cannot be reached the
/// bill is queued as [BillSyncState.pending] and returned as saved. A failure
/// that is *not* a connection problem (a 422 the server will repeat, an expired
/// session) is rethrown — retrying it blindly would loop forever.
///
/// **Guest.** There is nothing to upload, so bills are device-only
/// ([BillsSource.device]), the demo bill is seeded once, and reading a photo is
/// refused with a message that points at signing in.
///
/// **[database] may be null** where the platform has no sqflite plugin (web,
/// Windows, Linux): the cache and the queue are then skipped, and a guest keeps
/// their bills in memory for the run.
final class BillRepositoryImpl implements BillRepository {
  BillRepositoryImpl({
    required BillRemoteDataSource remote,
    required String Function() ownerId,
    required bool Function() hasSession,
    AppDatabase? database,
    Bill? seed,
    DateTime Function()? now,
  }) : _remote = remote,
       _ownerId = ownerId,
       _hasSession = hasSession,
       _database = database,
       _seed = seed,
       _now = now ?? DateTime.now;

  final BillRemoteDataSource _remote;

  /// The cache partition: the account id, or `'guest'`. Read per call.
  final String Function() _ownerId;

  /// True while an access token exists.
  final bool Function() _hasSession;

  final AppDatabase? _database;

  /// The demo bill written on a guest's first visit; null for an account.
  final Bill? _seed;
  final DateTime Function() _now;

  /// Guest bills when there is no database to keep them in.
  final List<Bill> _memoryBills = <Bill>[];

  int _sequence = 0;

  /// Shared by concurrent loads so one queued bill is never confirmed twice.
  ///
  /// Bloc handlers for different events run concurrently, so a `BillsStarted`
  /// and a `BillsReloaded` can overlap; without this guard both would read the
  /// same queue and send the same bill.
  Future<void>? _flushing;

  @override
  Future<BillsSnapshot> fetchBills() async {
    if (!_hasSession()) return _guestSnapshot();

    final String owner = _ownerId();
    await _flushPending(owner);

    final AppDatabase? database = _database;
    try {
      final List<Bill> remote = await _remote.fetchAll();
      if (database == null) {
        return BillsSnapshot(bills: remote, source: BillsSource.server);
      }

      await database.replaceServerBills(owner, _rows(remote));
      return BillsSnapshot(
        bills: await _readCache(database, owner),
        source: BillsSource.server,
      );
    } on BillFailure catch (failure) {
      if (!failure.isOffline || database == null) rethrow;
      return BillsSnapshot(
        bills: await _readCache(database, owner),
        source: BillsSource.cache,
      );
    }
  }

  @override
  Future<Bill> save(Bill bill) async {
    if (!_hasSession()) return _saveGuest(bill);

    final String owner = _ownerId();
    final AppDatabase? database = _database;

    try {
      final Bill saved = await _remote.confirm(bill);
      if (database != null) {
        await database.saveBill(owner, BillRowMapper.toRows(saved));
      }
      return saved;
    } on BillFailure catch (failure) {
      if (!failure.isOffline || database == null) rethrow;

      final Bill queued = bill.copyWith(
        id: bill.isSaved ? bill.id : _nextLocalId('local'),
        syncState: BillSyncState.pending,
        isSample: false,
      );
      await database.saveBill(owner, BillRowMapper.toRows(queued));
      return queued;
    }
  }

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    // A photo cannot be read on the device, so this is the one operation a
    // guest cannot fall back to anything local for.
    if (!_hasSession()) {
      throw const BillFailure(
        'Reading a photo needs the scanner. Sign in to use it.',
      );
    }
    return _remote.extract(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }

  // ---------------------------------------------------------------------------
  // Guest mode — device-only bills
  // ---------------------------------------------------------------------------

  /// A guest has no server list, so a read is the local one, with the demo bill
  /// seeded the first time.
  Future<BillsSnapshot> _guestSnapshot() async {
    final String owner = _ownerId();
    final AppDatabase? database = _database;

    if (database == null) {
      await _seedMemory();
      final List<Bill> bills = List<Bill>.of(_memoryBills)
        ..sort((Bill a, Bill b) => b.date.compareTo(a.date));
      return BillsSnapshot(
        bills: List<Bill>.unmodifiable(bills),
        source: BillsSource.device,
      );
    }

    await _seedOnce(database, owner);
    return BillsSnapshot(
      bills: await _readCache(database, owner),
      source: BillsSource.device,
    );
  }

  Future<Bill> _saveGuest(Bill bill) async {
    final Bill saved = bill.copyWith(
      id: bill.isSaved ? bill.id : _nextLocalId('guest'),
      isSample: false,
      syncState: BillSyncState.synced,
    );

    final AppDatabase? database = _database;
    if (database == null) {
      final int index = _memoryBills.indexWhere(
        (Bill existing) => existing.id == saved.id,
      );
      if (index == -1) {
        _memoryBills.add(saved);
      } else {
        _memoryBills[index] = saved;
      }
      return saved;
    }

    await database.saveBill(_ownerId(), BillRowMapper.toRows(saved));
    return saved;
  }

  /// Writes the demo bill once, so a guest always has something to look at.
  Future<void> _seedOnce(AppDatabase database, String owner) async {
    final Bill? seed = _seed;
    if (seed == null || await database.hasBills(owner)) return;

    await database.saveBill(owner, BillRowMapper.toRows(_asGuestBill(seed)));
  }

  Future<void> _seedMemory() async {
    final Bill? seed = _seed;
    if (seed == null || _memoryBills.isNotEmpty) return;
    _memoryBills.add(_asGuestBill(seed));
  }

  Bill _asGuestBill(Bill seed) {
    return seed.copyWith(
      id: 'guest-demo',
      isSample: false,
      syncState: BillSyncState.synced,
    );
  }

  // ---------------------------------------------------------------------------
  // Cache and queue
  // ---------------------------------------------------------------------------

  /// Bills plus their items, read through two queries instead of one per bill.
  Future<List<Bill>> _readCache(AppDatabase database, String owner) async {
    final List<Map<String, Object?>> billRows = await database.readBills(owner);
    final List<Map<String, Object?>> itemRows = await database.readItems(owner);

    final Map<String, List<BillItem>> itemsByBill = <String, List<BillItem>>{};
    for (final Map<String, Object?> row in itemRows) {
      final String billId = row['bill_id'] as String? ?? '';
      itemsByBill
          .putIfAbsent(billId, () => <BillItem>[])
          .add(BillRowMapper.itemFromRow(row));
    }

    return List<Bill>.unmodifiable(<Bill>[
      for (final Map<String, Object?> row in billRows)
        BillRowMapper.fromRows(
          row,
          items: itemsByBill[row['id']] ?? const <BillItem>[],
        ),
    ]);
  }

  List<BillRows> _rows(List<Bill> bills) {
    return <BillRows>[
      for (final Bill bill in bills) BillRowMapper.toRows(bill),
    ];
  }

  /// Starts a flush, or joins the one already running.
  Future<void> _flushPending(String owner) {
    final Future<void>? running = _flushing;
    if (running != null) return running;

    final Future<void> started = _flushQueue(owner).whenComplete(() {
      _flushing = null;
    });
    _flushing = started;
    return started;
  }

  /// Sends the queued bills oldest first.
  ///
  /// Stops at the first failure and leaves the rest queued: one rejected bill
  /// must not hide the others, and the next read retries.
  Future<void> _flushQueue(String owner) async {
    final AppDatabase? database = _database;
    if (database == null) return;

    final List<Map<String, Object?>> pendingRows = await database
        .readPendingBills(owner);

    for (final Map<String, Object?> row in pendingRows) {
      final Bill bill = BillRowMapper.fromRows(row);
      try {
        final Bill saved = await _remote.confirm(bill);
        await database.promotePending(
          owner,
          localId: bill.id,
          rows: BillRowMapper.toRows(saved),
        );
      } on BillFailure {
        return;
      }
    }
  }

  /// A device-only id, unique enough for one phone's queue.
  String _nextLocalId(String prefix) {
    return '$prefix-${_now().microsecondsSinceEpoch}-${++_sequence}';
  }
}

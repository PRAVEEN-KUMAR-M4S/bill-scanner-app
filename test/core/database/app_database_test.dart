import 'dart:io';

import 'package:bill_scanner/core/database/app_database.dart';
import 'package:bill_scanner/features/bills/data/models/bill_row_mapper.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Bill _bill({
  required String id,
  String merchant = 'Asha Tiffins',
  DateTime? date,
  double total = 100,
  BillCategory category = BillCategory.foodAndDrink,
  BillSyncState syncState = BillSyncState.synced,
  List<BillItem> items = const <BillItem>[],
}) {
  return Bill(
    id: id,
    merchant: merchant,
    date: date ?? DateTime(2026, 10, 20),
    total: total,
    category: category,
    items: items,
    syncState: syncState,
  );
}

void main() {
  sqfliteFfiInit();

  late DateTime clock;
  late AppDatabase database;

  /// Rows are built by the mapper, which is the only file that knows column
  /// names, so this test covers the mapper and the SQL together.
  Future<void> save(String ownerId, Bill bill) {
    return database.saveBill(ownerId, BillRowMapper.toRows(bill));
  }

  Future<List<Bill>> read(String ownerId) async {
    final List<Map<String, Object?>> billRows = await database.readBills(
      ownerId,
    );
    final List<Map<String, Object?>> itemRows = await database.readItems(
      ownerId,
    );

    return <Bill>[
      for (final Map<String, Object?> row in billRows)
        BillRowMapper.fromRows(
          row,
          items: <BillItem>[
            for (final Map<String, Object?> item in itemRows)
              if (item['bill_id'] == row['id']) BillRowMapper.itemFromRow(item),
          ],
        ),
    ];
  }

  setUp(() async {
    clock = DateTime(2026, 10, 26, 9);
    database = (await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: inMemoryDatabasePath,
      now: () => clock,
    ))!;
  });

  tearDown(() => database.close());

  test('creates both tables and their indexes', () async {
    final List<Map<String, Object?>> objects = await database.raw.rawQuery(
      "SELECT name, type FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
    );

    final List<String> tables = <String>[
      for (final Map<String, Object?> row in objects)
        if (row['type'] == 'table') row['name']! as String,
    ];
    final List<String> indexes = <String>[
      for (final Map<String, Object?> row in objects)
        if (row['type'] == 'index') row['name']! as String,
    ];

    expect(tables, containsAll(<String>['bills', 'bill_items']));
    expect(
      indexes,
      containsAll(<String>[
        'idx_bills_owner_date',
        'idx_bills_owner_sync',
        'idx_bill_items_bill',
      ]),
    );

    final List<Map<String, Object?>> version = await database.raw.rawQuery(
      'PRAGMA user_version',
    );
    expect(version.single['user_version'], AppDatabase.schemaVersion);
  });

  test('round-trips a bill, its items and an apostrophe in a name', () async {
    await save(
      '7',
      _bill(
        id: 'b1',
        merchant: "O'Brien Cafe",
        date: DateTime(2026, 10, 20),
        total: 250.5,
        items: const <BillItem>[
          BillItem(name: 'Chai', amount: 50, quantity: 2),
          BillItem(name: 'Cake', amount: 200.5),
        ],
      ),
    );

    final Bill loaded = (await read('7')).single;

    expect(loaded.id, 'b1');
    expect(loaded.merchant, "O'Brien Cafe");
    expect(loaded.date, DateTime(2026, 10, 20));
    expect(loaded.total, 250.5);
    expect(loaded.items.map((BillItem item) => item.name), <String>[
      'Chai',
      'Cake',
    ]);
    expect(loaded.items.first.quantity, 2);
    expect(loaded.syncState, BillSyncState.synced);
  });

  test('orders bills by date, newest first', () async {
    await save('7', _bill(id: 'old', date: DateTime(2026, 10, 2)));
    await save('7', _bill(id: 'new', date: DateTime(2026, 10, 22)));
    await save('7', _bill(id: 'mid', date: DateTime(2026, 10, 9)));

    expect((await read('7')).map((Bill bill) => bill.id), <String>[
      'new',
      'mid',
      'old',
    ]);
  });

  test('keeps each owner in its own partition', () async {
    await save('7', _bill(id: 'mine'));
    await save('guest', _bill(id: 'theirs'));

    expect((await read('7')).single.id, 'mine');
    expect((await read('guest')).single.id, 'theirs');
    expect(await database.hasBills('8'), isFalse);
    expect(await database.hasBills('7'), isTrue);
  });

  test('reads only pending bills, oldest first', () async {
    await save('7', _bill(id: 'server', date: DateTime(2026, 10, 1)));
    await save('7', _bill(id: 'p1', syncState: BillSyncState.pending));
    clock = clock.add(const Duration(seconds: 1));
    await save('7', _bill(id: 'p2', syncState: BillSyncState.pending));

    final List<Map<String, Object?>> pending = await database.readPendingBills(
      '7',
    );
    expect(pending.map((Map<String, Object?> row) => row['id']), <String>[
      'p1',
      'p2',
    ]);
    expect((await read('7')).length, 3);
  });

  test('a server refresh replaces synced rows but keeps the queue', () async {
    await save('7', _bill(id: 'stale'));
    await save('7', _bill(id: 'local-1', syncState: BillSyncState.pending));

    await database.replaceServerBills('7', <BillRows>[
      BillRowMapper.toRows(_bill(id: 'fresh')),
    ]);

    final List<Bill> bills = await read('7');
    expect(
      bills.map((Bill bill) => bill.id),
      containsAll(<String>['fresh', 'local-1']),
    );
    expect(bills.map((Bill bill) => bill.id), isNot(contains('stale')));
    expect(
      bills.firstWhere((Bill bill) => bill.id == 'local-1').isPendingSync,
      isTrue,
    );
  });

  test('a server row is always stored as synced', () async {
    await database.replaceServerBills('7', <BillRows>[
      BillRowMapper.toRows(
        _bill(id: 'fresh', syncState: BillSyncState.pending),
      ),
    ]);

    expect((await read('7')).single.syncState, BillSyncState.synced);
  });

  test(
    'promoting a queued bill swaps the local id for the server id',
    () async {
      await save(
        '7',
        _bill(
          id: 'local-1',
          syncState: BillSyncState.pending,
          items: const <BillItem>[BillItem(name: 'Tea', amount: 10)],
        ),
      );

      await database.promotePending(
        '7',
        localId: 'local-1',
        rows: BillRowMapper.toRows(
          _bill(
            id: 'server-9',
            items: const <BillItem>[BillItem(name: 'Tea', amount: 10)],
          ),
        ),
      );

      expect(await database.readPendingBills('7'), isEmpty);
      expect((await read('7')).single.id, 'server-9');

      // The removed local row's items went with it, via ON DELETE CASCADE.
      final List<Map<String, Object?>> itemRows = await database.raw.rawQuery(
        'SELECT COUNT(*) AS item_count FROM bill_items',
      );
      expect(itemRows.single['item_count'], 1);
    },
  );

  test('a closed database file reopens with its rows intact', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'bill_scan_test',
    );
    addTearDown(() => directory.delete(recursive: true));

    final String filePath = p.join(directory.path, 'bills.db');
    final AppDatabase first = (await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: filePath,
      now: () => clock,
    ))!;
    await first.saveBill(
      '7',
      BillRowMapper.toRows(_bill(id: 'persisted', total: 42)),
    );
    await first.close();

    final AppDatabase second = (await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: filePath,
    ))!;
    addTearDown(second.close);

    final List<Map<String, Object?>> rows = await second.readBills('7');
    expect(rows.single['id'], 'persisted');
    expect(rows.single['total'], 42);
  });

  test(
    're-saving a bill replaces its items instead of duplicating them',
    () async {
      await save(
        '7',
        _bill(
          id: 'b1',
          items: const <BillItem>[
            BillItem(name: 'Old one', amount: 10),
            BillItem(name: 'Old two', amount: 20),
          ],
        ),
      );
      await save(
        '7',
        _bill(
          id: 'b1',
          items: const <BillItem>[BillItem(name: 'New', amount: 30)],
        ),
      );

      final Bill loaded = (await read('7')).single;
      expect(loaded.items.map((BillItem item) => item.name), <String>['New']);
    },
  );
}

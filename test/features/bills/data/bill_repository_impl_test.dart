import 'package:bill_scanner/core/database/app_database.dart';
import 'package:bill_scanner/features/bills/data/datasources/bill_remote_datasource.dart';
import 'package:bill_scanner/features/bills/data/repositories/bill_repository_impl.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_problem.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_sync_state.dart';
import 'package:bill_scanner/features/bills/domain/entities/bills_snapshot.dart';
import 'package:bill_scanner/features/bills/domain/failures/bill_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Bill _bill({
  String id = '',
  String merchant = 'Chai Point',
  double total = 120,
  DateTime? date,
}) {
  return Bill(
    id: id,
    merchant: merchant,
    date: date ?? DateTime(2026, 10, 22),
    total: total,
    category: BillCategory.foodAndDrink,
    items: const <BillItem>[BillItem(name: 'Chai', amount: 120)],
  );
}

/// The API, knocked offline on demand.
class _FakeRemote implements BillRemoteDataSource {
  bool online = true;
  BillFailure? saveFailure;
  List<Bill> stored = <Bill>[];
  final List<Bill> confirmed = <Bill>[];
  int fetches = 0;

  @override
  Future<List<Bill>> fetchAll() async {
    fetches++;
    if (!online) throw const BillFailure.offline('offline');
    return List<Bill>.unmodifiable(stored);
  }

  @override
  Future<Bill> confirm(Bill bill) async {
    if (!online) throw const BillFailure.offline('offline');
    if (saveFailure != null) throw saveFailure!;

    confirmed.add(bill);
    final Bill saved = bill.copyWith(
      id: 'server-${confirmed.length}',
      syncState: BillSyncState.synced,
    );
    stored = <Bill>[saved, ...stored];
    return saved;
  }

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  sqfliteFfiInit();

  late DateTime clock;
  late _FakeRemote remote;
  late AppDatabase database;
  late String owner;
  late bool signedIn;
  late BillRepositoryImpl repository;

  BillRepositoryImpl repositoryWith({
    required _FakeRemote remote,
    required AppDatabase? database,
  }) {
    return BillRepositoryImpl(
      remote: remote,
      database: database,
      // The same partition rule the injector uses: an account id when there is
      // a session, `'guest'` otherwise.
      ownerId: () => signedIn ? owner : 'guest',
      hasSession: () => signedIn,
      seed: _bill(
        id: '',
        merchant: 'Asha Tiffins',
        date: DateTime(2026, 10, 1),
      ),
      now: () => clock,
    );
  }

  setUp(() async {
    clock = DateTime(2026, 10, 26, 9);
    remote = _FakeRemote();
    database = (await AppDatabase.open(
      factory: databaseFactoryFfi,
      filePath: inMemoryDatabasePath,
      now: () => clock,
    ))!;
    owner = '7';
    signedIn = true;
    repository = repositoryWith(remote: remote, database: database);
  });

  tearDown(() => database.close());

  group('signed in', () {
    test(
      'caches a server list and serves it when the connection drops',
      () async {
        remote.stored = <Bill>[_bill(id: 'b1', merchant: 'Asha Tiffins')];

        final BillsSnapshot online = await repository.fetchBills();
        expect(online.source, BillsSource.server);
        expect(online.bills.single.id, 'b1');

        remote.online = false;
        final BillsSnapshot offline = await repository.fetchBills();

        expect(offline.isOffline, isTrue);
        expect(offline.bills.single.merchant, 'Asha Tiffins');
        expect(offline.pendingCount, 0);
      },
    );

    test('a save made offline is queued and visible as pending', () async {
      remote.online = false;

      final Bill saved = await repository.save(_bill());

      expect(saved.isPendingSync, isTrue);
      expect(saved.id, startsWith('local-'));

      final BillsSnapshot snapshot = await repository.fetchBills();
      expect(snapshot.isOffline, isTrue);
      expect(snapshot.pendingCount, 1);
      expect(snapshot.bills.single.merchant, 'Chai Point');
    });

    test('the queue is flushed on the next successful load', () async {
      remote.online = false;
      await repository.save(_bill());

      remote.online = true;
      final BillsSnapshot snapshot = await repository.fetchBills();

      expect(remote.confirmed.single.merchant, 'Chai Point');
      expect(snapshot.source, BillsSource.server);
      expect(snapshot.pendingCount, 0);
      expect(snapshot.bills.single.id, 'server-1');
      expect(snapshot.bills.single.syncState, BillSyncState.synced);
    });

    test('a validation failure is rethrown instead of being queued', () async {
      remote.saveFailure = const BillFailure(
        'Fix the highlighted fields before saving.',
        problems: <BillProblem>[
          BillProblem(field: 'total', message: 'Total must be positive'),
        ],
      );

      await expectLater(
        repository.save(_bill()),
        throwsA(
          isA<BillFailure>().having(
            (BillFailure failure) => failure.problems.length,
            'problems',
            1,
          ),
        ),
      );
      expect(await database.readBills(owner), isEmpty);
    });

    test('two overlapping loads confirm a queued bill only once', () async {
      remote.online = false;
      await repository.save(_bill());

      remote.online = true;
      final List<BillsSnapshot> snapshots = await Future.wait(
        <Future<BillsSnapshot>>[
          repository.fetchBills(),
          repository.fetchBills(),
        ],
      );

      expect(remote.confirmed.length, 1);
      expect(snapshots.every((BillsSnapshot s) => s.pendingCount == 0), isTrue);
    });

    test(
      'a rejected queued bill stays queued when a later load works',
      () async {
        remote.online = false;
        await repository.save(_bill());

        remote.online = true;
        remote.saveFailure = const BillFailure('The server had a problem.');

        final BillsSnapshot snapshot = await repository.fetchBills();

        expect(snapshot.pendingCount, 1);
        expect(snapshot.bills.single.isPendingSync, isTrue);
        expect(remote.confirmed, isEmpty);
      },
    );

    test('cache reads are scoped to the signed-in owner', () async {
      remote.online = false;
      await repository.save(_bill(merchant: 'Only seven'));

      owner = '8';
      remote.online = true;
      expect((await repository.fetchBills()).bills, isEmpty);

      owner = '7';
      remote.online = false;
      final BillsSnapshot back = await repository.fetchBills();

      expect(back.bills.single.merchant, 'Only seven');
      expect(back.pendingCount, 1);
    });
  });

  group('guest', () {
    setUp(() => signedIn = false);

    test('seeds the demo bill once, then keeps device saves', () async {
      final BillsSnapshot first = await repository.fetchBills();
      expect(first.source, BillsSource.device);
      expect(first.bills.single.id, 'guest-demo');
      expect(first.bills.single.isSample, isFalse);

      final Bill saved = await repository.save(
        Bill(
          id: '',
          merchant: 'Metro Card',
          date: DateTime(2026, 10, 20),
          total: 200,
          category: BillCategory.travel,
          items: const <BillItem>[],
        ),
      );

      expect(saved.id, startsWith('guest-'));
      expect(saved.isPendingSync, isFalse);
      expect(remote.confirmed, isEmpty);

      final BillsSnapshot second = await repository.fetchBills();
      expect(second.bills.length, 2);
      expect(second.bills.first.merchant, 'Metro Card');
    });

    test('scanning is refused without an account', () async {
      await expectLater(
        repository.extract(
          bytes: <int>[1],
          filename: 'bill.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(isA<BillFailure>()),
      );
    });

    test('the session is read per call, not once at construction', () async {
      final BillsSnapshot guest = await repository.fetchBills();
      expect(guest.source, BillsSource.device);
      expect(guest.bills.single.id, 'guest-demo');

      signedIn = true;
      remote.stored = <Bill>[_bill(id: 'b1', merchant: 'Asha Tiffins')];
      final BillsSnapshot account = await repository.fetchBills();

      expect(account.source, BillsSource.server);
      expect(account.bills.single.id, 'b1');
      // The guest partition is untouched by the signed-in read.
      expect(await database.readBills('guest'), hasLength(1));
    });
  });

  group('without a local database', () {
    test('a guest keeps bills in memory for the run', () async {
      signedIn = false;
      final BillRepositoryImpl memory = repositoryWith(
        remote: remote,
        database: null,
      );

      expect((await memory.fetchBills()).bills.single.id, 'guest-demo');

      final Bill saved = await memory.save(
        _bill(merchant: 'Metro Card', date: DateTime(2026, 10, 20)),
      );
      expect(saved.id, startsWith('guest-'));

      final BillsSnapshot snapshot = await memory.fetchBills();
      expect(snapshot.source, BillsSource.device);
      expect(snapshot.bills.first.merchant, 'Metro Card');
    });

    test('a signed-in read cannot fall back to a cache', () async {
      final BillRepositoryImpl memory = repositoryWith(
        remote: remote,
        database: null,
      );
      remote.stored = <Bill>[_bill(id: 'b1')];
      expect((await memory.fetchBills()).source, BillsSource.server);

      remote.online = false;
      await expectLater(memory.fetchBills(), throwsA(isA<BillFailure>()));
      await expectLater(memory.save(_bill()), throwsA(isA<BillFailure>()));
    });
  });
}

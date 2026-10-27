import 'package:bill_scanner/app.dart';
import 'package:bill_scanner/core/database/app_database.dart';
import 'package:bill_scanner/core/di/injector.dart';
import 'package:bill_scanner/core/navigation/app_shell.dart';
import 'package:bill_scanner/core/network/api_service.dart';
import 'package:bill_scanner/features/auth/domain/entities/user.dart';
import 'package:bill_scanner/features/bills/data/datasources/bill_remote_datasource.dart';
import 'package:bill_scanner/features/bills/data/models/bill_row_mapper.dart';
import 'package:bill_scanner/features/bills/data/repositories/bill_repository_impl.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_sync_state.dart';
import 'package:bill_scanner/features/bills/presentation/pages/bills_page.dart';
import 'package:bill_scanner/features/home/presentation/pages/home_page.dart';
import 'package:bill_scanner/features/review/presentation/pages/review_page.dart';
import 'package:bill_scanner/features/scan/data/repositories/scan_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_camera_driver.dart';

const User _user = User(id: '7', name: 'Asha Tiffins', email: 'asha@billo.app');
const String _owner = '7';

Bill _bill({
  required String id,
  String merchant = 'Asha Tiffins',
  double total = 680,
  DateTime? date,
  BillSyncState syncState = BillSyncState.synced,
}) {
  return Bill(
    id: id,
    merchant: merchant,
    date: date ?? DateTime(2026, 10, 1),
    total: total,
    category: BillCategory.foodAndDrink,
    items: const <BillItem>[BillItem(name: 'Tiffin', amount: 680)],
    syncState: syncState,
  );
}

Widget _app(BillRepositoryImpl bills) {
  return BillScannerApp(
    dependencies: AppDependencies(
      authRepository: FakeAuthRepository(latency: Duration.zero),
      billRepository: bills,
      scanRepository: ScanRepositoryImpl(
        bills: bills,
        hasSession: () => true,
        guestLatency: Duration.zero,
      ),
      createCamera: FakeCameraDriver.new,
      restoredUser: _user,
    ),
  );
}

/// The real repository, pointed at a server that cannot be reached.
///
/// Every call goes through the real data source, failure mapping, cache and
/// upload queue — only the socket is fake.
BillRepositoryImpl _offlineRepository(AppDatabase database) {
  return BillRepositoryImpl(
    remote: BillRemoteDataSource(
      ApiService(
        baseUrl: Uri.parse('http://api.test'),
        client: MockClient((http.Request request) async {
          throw http.ClientException('offline');
        }),
        accessToken: () async => 'access-1',
      ),
    ),
    database: database,
    ownerId: () => _owner,
    hasSession: () => true,
    now: () => DateTime(2026, 10, 26, 9),
  );
}

Finder _inPage(Type page, Finder matching) {
  return find.descendant(of: find.byType(page), matching: matching);
}

Finder _navTab(String label) {
  return find.descendant(
    of: find.byType(AppBottomNav),
    matching: find.text(label),
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database, {
  Size size = const Size(390, 844),
}) async {
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(_app(_offlineRepository(database)));
  await tester.pumpAndSettle();
}

Future<void> _openReview(WidgetTester tester) async {
  final Finder addBill = _inPage(HomePage, find.text('Add a bill'));
  await tester.ensureVisible(addBill);
  await tester.pumpAndSettle();
  await tester.tap(addBill);
  await tester.pumpAndSettle();

  final Finder sample = find.text('Just looking around?');
  await tester.ensureVisible(sample);
  await tester.pumpAndSettle();
  await tester.tap(sample);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final Finder saveBill = find.text('Save bill');
  await tester.ensureVisible(saveBill);
  await tester.pumpAndSettle();
  await tester.tap(saveBill);
  await tester.pumpAndSettle();
}

void main() {
  // Widget tests run the database on the calling isolate: the real schema and
  // the real statements, without the background isolate `databaseFactoryFfi`
  // uses.
  sqfliteFfiInit();

  late AppDatabase database;

  setUp(() async {
    database = (await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      filePath: inMemoryDatabasePath,
      now: () => DateTime(2026, 10, 26, 9),
    ))!;
  });

  tearDown(() => database.close());

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// Puts one bill in the cache the way the repository does.
  Future<void> seed(Bill bill) {
    return database.saveBill(_owner, BillRowMapper.toRows(bill));
  }

  testWidgets('a cached list explains it is offline on both tabs', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(_bill(id: 'b1'));

    await _pump(tester, database);

    expect(
      _inPage(HomePage, find.text('Offline · showing saved bills')),
      findsOneWidget,
    );
    expect(_inPage(HomePage, find.text('Asha Tiffins')), findsOneWidget);

    await tester.tap(_navTab('Bills'));
    await tester.pumpAndSettle();

    expect(
      _inPage(BillsPage, find.text('Offline · showing saved bills')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a queued bill is badged and counted', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await seed(
      _bill(
        id: 'local-1',
        merchant: 'Chai Point',
        syncState: BillSyncState.pending,
      ),
    );

    await _pump(tester, database);

    expect(
      _inPage(HomePage, find.text('Offline · 1 bill waiting to sync')),
      findsOneWidget,
    );
    expect(_inPage(HomePage, find.text('Pending sync')), findsOneWidget);
  });

  testWidgets('saving while offline queues the bill and says so', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, database, size: const Size(320, 568));

    await _openReview(tester);
    expect(find.byType(ReviewPage), findsOneWidget);

    await _save(tester);

    expect(find.byType(ReviewPage), findsNothing);
    expect(
      find.text('Saved on this phone. It will sync when you are back online.'),
      findsOneWidget,
    );
    expect(
      _inPage(HomePage, find.text('Offline · 1 bill waiting to sync')),
      findsOneWidget,
    );
    expect(_inPage(HomePage, find.text('Pending sync')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('banner and pending badge fit small and wide screens', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final Size size in <Size>[
      const Size(320, 568),
      const Size(390, 844),
      const Size(800, 1000),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await seed(
        _bill(
          id: 'local-1',
          merchant: 'A rather long shop name that needs ellipsis',
          syncState: BillSyncState.pending,
        ),
      );

      await _pump(tester, database, size: size);
      expect(tester.takeException(), isNull, reason: 'home at $size');

      await tester.tap(_navTab('Bills'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'bills at $size');
    }
  });
}

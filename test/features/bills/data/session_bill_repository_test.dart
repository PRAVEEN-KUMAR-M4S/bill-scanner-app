import 'package:bill_scanner/features/bills/data/repositories/session_bill_repository.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/repositories/bill_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBillRepository implements BillRepository {
  _FakeBillRepository(this.label);

  final String label;
  final List<String> calls = <String>[];

  @override
  Future<List<Bill>> fetchBills() async {
    calls.add('list');
    return <Bill>[
      Bill(
        id: label,
        merchant: label,
        date: DateTime(2026, 10, 22),
        total: 1,
        category: BillCategory.other,
        items: const <BillItem>[],
      ),
    ];
  }

  @override
  Future<Bill> save(Bill bill) async {
    calls.add('save');
    return bill.copyWith(id: label);
  }

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    calls.add('extract');
    return BillExtraction(
      bill: Bill(
        id: label,
        merchant: label,
        date: DateTime(2026, 10, 22),
        total: 1,
        category: BillCategory.other,
        items: const <BillItem>[],
      ),
    );
  }
}

void main() {
  test('a guest uses the local repository for every operation', () async {
    final _FakeBillRepository remote = _FakeBillRepository('remote');
    final _FakeBillRepository local = _FakeBillRepository('local');
    final SessionBillRepository repository = SessionBillRepository(
      signedIn: remote,
      guest: local,
      hasSession: () => false,
    );

    expect((await repository.fetchBills()).single.id, 'local');
    expect(
      (await repository.save(Bill.empty(date: DateTime(2026, 10, 22)))).id,
      'local',
    );
    expect(
      (await repository.extract(
        bytes: <int>[1],
        filename: 'bill.png',
        contentType: 'image/png',
      )).bill.id,
      'local',
    );
    expect(local.calls, <String>['list', 'save', 'extract']);
    expect(remote.calls, isEmpty);
  });

  test('a signed-in session uses the API for every operation', () async {
    final _FakeBillRepository remote = _FakeBillRepository('remote');
    final _FakeBillRepository local = _FakeBillRepository('local');
    final SessionBillRepository repository = SessionBillRepository(
      signedIn: remote,
      guest: local,
      hasSession: () => true,
    );

    await repository.fetchBills();
    await repository.save(Bill.empty(date: DateTime(2026, 10, 22)));
    await repository.extract(
      bytes: <int>[1],
      filename: 'bill.png',
      contentType: 'image/png',
    );

    expect(remote.calls, <String>['list', 'save', 'extract']);
    expect(local.calls, isEmpty);
  });

  test('the decision is read per call, not once at construction', () async {
    bool signedIn = false;
    final _FakeBillRepository remote = _FakeBillRepository('remote');
    final _FakeBillRepository local = _FakeBillRepository('local');
    final SessionBillRepository repository = SessionBillRepository(
      signedIn: remote,
      guest: local,
      hasSession: () => signedIn,
    );

    await repository.fetchBills();
    signedIn = true;
    await repository.fetchBills();

    expect(local.calls, <String>['list']);
    expect(remote.calls, <String>['list']);
  });
}

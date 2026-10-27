import 'package:bill_scanner/features/bills/data/sample_bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_sync_state.dart';
import 'package:bill_scanner/features/bills/domain/entities/bills_snapshot.dart';
import 'package:bill_scanner/features/bills/domain/repositories/bill_repository.dart';

/// In-memory stand-in for the bills backend, used by widget tests.
///
/// Starts with the bill shown in the design and keeps saved bills in memory,
/// newest first, so the dashboard and the list react to a new bill without a
/// network or a database.
class FakeBillRepository implements BillRepository {
  FakeBillRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final Bill sample = buildSampleBill(_now());
    _bills.add(sample.copyWith(id: 'bill-demo', isSample: false));
  }

  /// Simulated round-trip time.
  final Duration latency;
  final DateTime Function() _now;
  final List<Bill> _bills = <Bill>[];
  int _nextId = 0;

  @override
  Future<BillsSnapshot> fetchBills() async {
    await Future<void>.delayed(latency);
    return BillsSnapshot(
      bills: List<Bill>.unmodifiable(_bills),
      source: BillsSource.device,
    );
  }

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    await Future<void>.delayed(latency);
    return BillExtraction(bill: buildSampleBill(_now()));
  }

  @override
  Future<Bill> save(Bill bill) async {
    await Future<void>.delayed(latency);

    final Bill saved = bill.copyWith(
      id: bill.isSaved ? bill.id : 'bill-${++_nextId}',
      isSample: false,
      syncState: BillSyncState.synced,
    );

    final int existing = _bills.indexWhere((Bill b) => b.id == saved.id);
    if (existing == -1) {
      _bills.insert(0, saved);
    } else {
      _bills[existing] = saved;
    }
    return saved;
  }
}

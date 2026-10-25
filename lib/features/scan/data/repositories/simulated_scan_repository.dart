import '../../../bills/data/sample_bill.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_extraction.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/scan_source.dart';
import '../../domain/repositories/scan_repository.dart';

/// Stand-in for the camera + scanner pipeline.
///
/// Returns the bundled demo bill after a delay long enough for the scanning
/// state to be visible, which keeps the whole capture flow testable without a
/// device camera or an API.
class SimulatedScanRepository implements ScanRepository {
  SimulatedScanRepository({
    this.latency = const Duration(milliseconds: 1200),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration latency;
  final DateTime Function() _now;

  @override
  Bill get sampleBill => buildSampleBill(_now());

  @override
  Future<BillExtraction?> capture(ScanSource source) async {
    await Future<void>.delayed(latency);
    return BillExtraction(bill: buildSampleBill(_now()));
  }

  @override
  Future<BillExtraction> read(CapturedPhoto photo) async {
    await Future<void>.delayed(latency);
    return BillExtraction(bill: buildSampleBill(_now()));
  }
}

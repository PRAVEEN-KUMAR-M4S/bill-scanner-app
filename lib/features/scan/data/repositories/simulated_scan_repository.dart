import '../../../bills/data/sample_bill.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../domain/repositories/scan_repository.dart';

/// Stand-in for the camera + OCR pipeline.
///
/// Returns the bundled demo bill after a delay long enough for the scanning
/// state to be visible, which keeps the whole capture flow testable without a
/// device camera.
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
  Future<Bill> captureBill() async {
    await Future<void>.delayed(latency);
    return buildSampleBill(_now());
  }
}

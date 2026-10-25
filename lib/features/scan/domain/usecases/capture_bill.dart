import '../../../bills/domain/entities/bill_extraction.dart';
import '../entities/scan_source.dart';
import '../repositories/scan_repository.dart';

/// Picks a photo and returns the bill the scanner read from it.
class CaptureBill {
  const CaptureBill(this._repository);

  final ScanRepository _repository;

  Future<BillExtraction?> call(ScanSource source) =>
      _repository.capture(source);
}

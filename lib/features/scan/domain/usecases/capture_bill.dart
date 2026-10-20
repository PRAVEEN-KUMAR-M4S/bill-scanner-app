import '../../../bills/domain/entities/bill.dart';
import '../repositories/scan_repository.dart';

/// Captures a photo and returns the bill the scanner read from it.
class CaptureBill {
  const CaptureBill(this._repository);

  final ScanRepository _repository;

  Future<Bill> call() => _repository.captureBill();
}

import '../../../bills/domain/entities/bill_extraction.dart';
import '../entities/captured_photo.dart';
import '../repositories/scan_repository.dart';

/// Reads a photo that is already captured and returns the draft it produced.
///
/// This is the second half of the scan flow: the shutter takes the picture and
/// this sends it to the scanner. The picker path ([CaptureBill]) still does
/// both in one call.
class ReadPhoto {
  const ReadPhoto(this._repository);

  final ScanRepository _repository;

  Future<BillExtraction> call(CapturedPhoto photo) => _repository.read(photo);
}

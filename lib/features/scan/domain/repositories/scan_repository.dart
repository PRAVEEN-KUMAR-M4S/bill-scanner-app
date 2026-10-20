import '../../../bills/domain/entities/bill.dart';

/// Source of the photos that turn into a bill.
///
/// The real implementation will wrap the camera and the OCR service; today a
/// simulated scan returns the bundled sample after a short delay.
abstract interface class ScanRepository {
  /// Reads the bill in frame and returns the extracted values.
  Future<Bill> captureBill();

  /// The bundled demo bill shown by "Just looking around?".
  Bill get sampleBill;
}

import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_extraction.dart';
import '../entities/captured_photo.dart';
import '../entities/scan_source.dart';

/// Source of the photos that turn into a bill.
///
/// [ApiScanRepository] picks a photo and calls the bill scanner; the simulated
/// implementation returns the bundled sample so tests and previews need no
/// camera or plugin.
abstract interface class ScanRepository {
  /// Lets the person choose a photo and returns the scanner's draft.
  ///
  /// Returns `null` when the picker was cancelled. A failure is a
  /// `BillFailure`/exception the bloc can show.
  Future<BillExtraction?> capture(ScanSource source);

  /// Sends a photo that is already in hand (the shutter, or a picked file)
  /// to the scanner.
  ///
  /// The caller decides what "already taken" means: the camera screen owns
  /// the bytes, this only reads them.
  Future<BillExtraction> read(CapturedPhoto photo);

  /// The bundled demo bill shown by "Just looking around?".
  Bill get sampleBill;
}

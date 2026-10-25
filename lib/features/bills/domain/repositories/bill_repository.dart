import '../entities/bill.dart';
import '../entities/bill_extraction.dart';

/// Storage and extraction contract for bills.
///
/// Implemented by the API repository in production and by an in-memory store
/// in tests and previews.
abstract interface class BillRepository {
  /// Every saved bill, newest first.
  Future<List<Bill>> fetchBills();

  /// Confirms [bill] as a draft and returns the stored version with its id.
  Future<Bill> save(Bill bill);

  /// Sends one JPG/PNG photo to the scanner and returns the draft plus the
  /// fields the checks flagged. Nothing is stored by this call.
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  });
}

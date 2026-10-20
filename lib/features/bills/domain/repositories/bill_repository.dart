import '../entities/bill.dart';

/// Storage contract for saved bills. Implemented by the in-memory store today
/// and by a real backend later.
abstract interface class BillRepository {
  /// Every saved bill, newest first.
  Future<List<Bill>> fetchBills();

  /// Persists [bill] and returns the stored version (with its assigned id).
  Future<Bill> save(Bill bill);
}

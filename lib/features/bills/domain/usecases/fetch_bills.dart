import '../entities/bills_snapshot.dart';
import '../repositories/bill_repository.dart';

/// Loads the current bill list, syncing and caching when the store supports it.
class FetchBills {
  const FetchBills(this._repository);

  final BillRepository _repository;

  Future<BillsSnapshot> call() => _repository.fetchBills();
}

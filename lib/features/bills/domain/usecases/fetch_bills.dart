import '../entities/bill.dart';
import '../repositories/bill_repository.dart';

/// Loads every saved bill, newest first.
class FetchBills {
  const FetchBills(this._repository);

  final BillRepository _repository;

  Future<List<Bill>> call() => _repository.fetchBills();
}

import '../entities/bill.dart';
import '../repositories/bill_repository.dart';

/// Persists a bill that has been checked on the review screen.
class SaveBill {
  const SaveBill(this._repository);

  final BillRepository _repository;

  Future<Bill> call(Bill bill) => _repository.save(bill);
}

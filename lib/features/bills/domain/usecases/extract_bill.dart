import '../entities/bill_extraction.dart';
import '../repositories/bill_repository.dart';

/// Sends a bill photo to the scanner and returns an editable draft.
class ExtractBill {
  const ExtractBill(this._repository);

  final BillRepository _repository;

  Future<BillExtraction> call({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    return _repository.extract(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }
}

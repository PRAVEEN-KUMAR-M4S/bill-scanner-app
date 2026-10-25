import '../../domain/entities/bill.dart';
import '../../domain/entities/bill_extraction.dart';
import '../../domain/repositories/bill_repository.dart';

/// Routes bill operations to the API for a signed-in account and to a local
/// store for a guest.
///
/// Guest mode has no access token, so an API-only repository would answer
/// "session expired" on the dashboard. Keeping the decision in the data layer
/// means no bloc or page has to branch on authentication.
final class SessionBillRepository implements BillRepository {
  const SessionBillRepository({
    required this.signedIn,
    required this.guest,
    required this.hasSession,
  });

  /// API-backed repository used when an access token exists.
  final BillRepository signedIn;

  /// In-memory repository used by a guest (and its demo bill).
  final BillRepository guest;

  /// Reads `AuthTokenStore.hasSession` at call time, not at construction time.
  final bool Function() hasSession;

  BillRepository get _active => hasSession() ? signedIn : guest;

  @override
  Future<List<Bill>> fetchBills() => _active.fetchBills();

  @override
  Future<Bill> save(Bill bill) => _active.save(bill);

  @override
  Future<BillExtraction> extract({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) {
    return _active.extract(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
  }
}

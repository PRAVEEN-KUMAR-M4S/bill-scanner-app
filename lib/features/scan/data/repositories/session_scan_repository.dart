import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_extraction.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/scan_source.dart';
import '../../domain/repositories/scan_repository.dart';

/// Picks the scanner that matches the current session.
///
/// A signed-in account uploads to `/bills/extract`; a guest has no token and
/// keeps the local simulated capture, so the demo flow still works offline.
final class SessionScanRepository implements ScanRepository {
  const SessionScanRepository({
    required this.signedIn,
    required this.guest,
    required this.hasSession,
  });

  final ScanRepository signedIn;
  final ScanRepository guest;
  final bool Function() hasSession;

  ScanRepository get _active => hasSession() ? signedIn : guest;

  @override
  Future<BillExtraction?> capture(ScanSource source) => _active.capture(source);

  @override
  Future<BillExtraction> read(CapturedPhoto photo) => _active.read(photo);

  @override
  Bill get sampleBill => _active.sampleBill;
}

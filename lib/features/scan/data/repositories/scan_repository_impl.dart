import 'package:image_picker/image_picker.dart';

import '../../../bills/data/sample_bill.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_extraction.dart';
import '../../../bills/domain/repositories/bill_repository.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/scan_source.dart';
import '../../domain/repositories/scan_repository.dart';

/// The capture path: a photo from the camera or the library, read by the bill
/// scanner.
///
/// A signed-in account uploads through [BillRepository.extract], which is where
/// the token, the failure messages and the API live. A guest has no token, so
/// the bundled demo bill is returned after a short delay and the whole flow
/// stays usable — that is also what makes the flow testable without a device
/// camera.
///
/// Nothing is stored here: the scan screen holds the draft until the person
/// confirms it on the review screen.
final class ScanRepositoryImpl implements ScanRepository {
  ScanRepositoryImpl({
    required BillRepository bills,
    required bool Function() hasSession,
    ImagePicker? picker,
    Future<XFile?> Function(ImageSource source)? pickImage,
    DateTime Function()? now,
    this.guestLatency = const Duration(milliseconds: 1200),
  }) : _bills = bills,
       _hasSession = hasSession,
       _picker = picker ?? ImagePicker(),
       _pickImage = pickImage,
       _now = now ?? DateTime.now;

  final BillRepository _bills;

  /// Read per call, so signing in changes the scanner without a rebuild.
  final bool Function() _hasSession;

  /// The plugin, or the injected replacement used by tests.
  final ImagePicker _picker;
  final Future<XFile?> Function(ImageSource source)? _pickImage;
  final DateTime Function() _now;

  /// How long the simulated guest reading takes; long enough for the scanning
  /// state to be visible.
  final Duration guestLatency;

  @override
  Bill get sampleBill => buildSampleBill(_now());

  @override
  Future<BillExtraction?> capture(ScanSource source) async {
    if (!_hasSession()) return _guestReport();

    final ImageSource imageSource = source == ScanSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final XFile? photo = _pickImage != null
        ? await _pickImage(imageSource)
        : await _picker.pickImage(
            source: imageSource,
            imageQuality: 90,
            maxWidth: 2400,
          );
    if (photo == null) return null;

    return read(
      CapturedPhoto(
        bytes: await photo.readAsBytes(),
        filename: photo.name,
        contentType: _contentType(photo),
      ),
    );
  }

  @override
  Future<BillExtraction> read(CapturedPhoto photo) async {
    if (!_hasSession()) return _guestReport();

    return _bills.extract(
      bytes: photo.bytes,
      filename: photo.filename,
      contentType: photo.contentType,
    );
  }

  /// The draft a guest gets: the demo bill, after a delay long enough for the
  /// scanning state to be seen.
  Future<BillExtraction> _guestReport() async {
    if (guestLatency > Duration.zero) {
      await Future<void>.delayed(guestLatency);
    }
    return BillExtraction(bill: buildSampleBill(_now()));
  }

  static String _contentType(XFile photo) {
    final String? mime = photo.mimeType?.toLowerCase();
    // Some Android pickers report the non-standard image/jpg.
    if (mime == 'image/jpg') return 'image/jpeg';
    return mime ?? _mimeFromName(photo.name);
  }

  static String _mimeFromName(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    return 'image/jpeg';
  }
}

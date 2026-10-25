import 'package:image_picker/image_picker.dart';

import '../../../bills/data/sample_bill.dart';
import '../../../bills/domain/entities/bill.dart';
import '../../../bills/domain/entities/bill_extraction.dart';
import '../../../bills/domain/repositories/bill_repository.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/scan_source.dart';
import '../../domain/repositories/scan_repository.dart';

/// The real capture path: a photo from the camera or library, then the bill
/// scanner through [BillRepository.extract].
///
/// No image bytes are kept after the request; the scanner stores nothing until
/// the person confirms the reviewed draft.
class ApiScanRepository implements ScanRepository {
  ApiScanRepository({
    required BillRepository billRepository,
    ImagePicker? picker,
    Future<XFile?> Function(ImageSource source)? pickImage,
    DateTime Function()? now,
  }) : _billRepository = billRepository,
       _picker = picker ?? ImagePicker(),
       _pickImage = pickImage,
       _now = now ?? DateTime.now;

  final BillRepository _billRepository;
  final ImagePicker _picker;
  final Future<XFile?> Function(ImageSource source)? _pickImage;
  final DateTime Function() _now;

  @override
  Bill get sampleBill => buildSampleBill(_now());

  @override
  Future<BillExtraction?> capture(ScanSource source) async {
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
  Future<BillExtraction> read(CapturedPhoto photo) {
    return _billRepository.extract(
      bytes: photo.bytes,
      filename: photo.filename,
      contentType: photo.contentType,
    );
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

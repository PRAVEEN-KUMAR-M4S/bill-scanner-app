import 'package:equatable/equatable.dart';

/// A photo that has already been taken: the shutter pressed, the bytes in
/// hand, nothing read yet.
///
/// The scan feature passes this from the capture screen to the repository so
/// the camera never talks to the network itself and the same path serves a
/// photo from any source.
class CapturedPhoto extends Equatable {
  const CapturedPhoto({
    required this.bytes,
    required this.filename,
    this.contentType = 'image/jpeg',
  });

  /// JPEG/PNG payload exactly as produced by the camera.
  final List<int> bytes;

  /// Name sent to the API; the extension carries the fallback content type.
  final String filename;

  /// MIME type the backend accepts, `image/jpeg` or `image/png`.
  final String contentType;

  @override
  List<Object?> get props => <Object?>[bytes, filename, contentType];
}

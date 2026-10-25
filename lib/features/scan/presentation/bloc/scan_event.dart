import 'package:equatable/equatable.dart';

import '../../domain/entities/scan_source.dart';

sealed class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Ask the system for camera access and start the preview.
///
/// Sent once when the camera screen opens, and again by the retry button when
/// access was refused.
final class ScanCameraRequested extends ScanEvent {
  const ScanCameraRequested();
}

/// Press the shutter: take the picture, then send it through the scanner.
final class ScanShutterPressed extends ScanEvent {
  const ScanShutterPressed();
}

/// Choose a photo from the library (or the system camera on the picker path).
final class ScanCaptureRequested extends ScanEvent {
  const ScanCaptureRequested(this.source);

  final ScanSource source;

  @override
  List<Object?> get props => <Object?>[source];
}

/// Switch the torch on or off while the preview is running.
final class ScanFlashToggled extends ScanEvent {
  const ScanFlashToggled();
}

/// Switch to the other lens.
final class ScanFlipRequested extends ScanEvent {
  const ScanFlipRequested();
}

/// Clear a failure and return to whatever the camera is doing now.
final class ScanResetRequested extends ScanEvent {
  const ScanResetRequested();
}

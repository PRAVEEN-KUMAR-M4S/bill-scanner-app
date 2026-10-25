import 'package:flutter/widgets.dart';

import '../../domain/entities/captured_photo.dart';

/// What the camera is doing right now.
///
/// The capture screen renders one state per value: the prompt while [idle],
/// the spinner while [starting], the preview while [live] and an explanation
/// when it is [denied] or [unavailable].
enum CameraStatus {
  /// Nothing has been asked for yet.
  idle,

  /// Permission is being requested and the preview is starting up.
  starting,

  /// Preview is running; the shutter may be pressed.
  live,

  /// The person said no (or the system will not ask again).
  denied,

  /// No camera on this device, or the platform cannot run one.
  unavailable,
}

/// The device camera, wrapped so the scan feature never talks to the plugin
/// directly and tests can drive the whole flow without a camera.
///
/// Implementations own the platform controller: [open] requests access and
/// starts the preview, [takePicture] returns the bytes for the scanner and
/// [close] releases everything. Presentation decides what each [CameraStatus]
/// looks like.
abstract interface class CameraDriver {
  /// Current permission/preview state.
  CameraStatus get status;

  /// True when more than one lens is available, so the flip control shows.
  bool get canFlip;

  /// True when a torch can be switched on at all.
  bool get hasFlash;

  /// Whether the torch is currently on.
  bool get flashOn;

  /// Asks for permission and starts the preview.
  ///
  /// Returns the resulting status so the caller can render the outcome.
  Future<CameraStatus> open();

  /// Switches to the other lens, if there is one.
  Future<void> flip();

  /// Toggles the torch and returns the state that was actually reached;
  /// `false` when the platform does not support it.
  Future<bool> setFlash(bool enabled);

  /// Presses the shutter. Returns `null` when the camera is not ready or the
  /// platform failed, so the caller can show a retry.
  Future<CapturedPhoto?> takePicture();

  /// Builds the live preview for the current status.
  Widget buildPreview(BuildContext context);

  /// Releases the camera. Called when the scan screen goes away.
  Future<void> close();
}

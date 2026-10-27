import 'package:bill_scanner/core/theme/app_colors.dart';
import 'package:bill_scanner/features/scan/domain/entities/captured_photo.dart';
import 'package:bill_scanner/features/scan/presentation/camera/camera_driver.dart';
import 'package:flutter/material.dart';

/// A camera that behaves like a real one without a device, used by widget
/// tests.
///
/// [open] can be told to report a denial so the blocked state is reachable, and
/// [buildPreview] draws a stand-in frame instead of a live texture.
class FakeCameraDriver implements CameraDriver {
  FakeCameraDriver({
    this.statusOnOpen = CameraStatus.live,
    this.latency = Duration.zero,
    this.lensCount = 2,
    this.torchSupported = true,
  });

  /// What `open()` reports: [CameraStatus.live] for the happy path and
  /// [CameraStatus.denied] to exercise the permission prompt's refusal.
  final CameraStatus statusOnOpen;

  /// Delay before the preview is ready, so the starting state is visible.
  final Duration latency;

  /// Number of lenses, which is what makes the flip control appear.
  final int lensCount;

  /// Whether the torch can be switched on.
  final bool torchSupported;

  CameraStatus _status = CameraStatus.idle;
  int _index = 0;
  bool _flashOn = false;
  int _captures = 0;
  int _opens = 0;

  @override
  CameraStatus get status => _status;

  @override
  bool get canFlip => lensCount > 1 && _status == CameraStatus.live;

  @override
  bool get hasFlash => torchSupported && _status == CameraStatus.live;

  @override
  bool get flashOn => _flashOn;

  /// How many successful shutter presses happened, for assertions in tests.
  int get captures => _captures;

  /// How many times access was asked for, so a retry is observable.
  int get opens => _opens;

  @override
  Future<CameraStatus> open() async {
    _opens += 1;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    _status = statusOnOpen;
    return _status;
  }

  @override
  Future<void> flip() async {
    if (!canFlip) return;
    _index = (_index + 1) % lensCount;
  }

  @override
  Future<bool> setFlash(bool enabled) async {
    if (!hasFlash) return false;
    _flashOn = enabled;
    return _flashOn;
  }

  @override
  Future<CapturedPhoto?> takePicture() async {
    if (_status != CameraStatus.live) return null;
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    _captures += 1;
    return CapturedPhoto(
      bytes: const <int>[0xFF, 0xD8, 0xFF, 0xD9],
      filename: 'capture-$_captures.jpg',
    );
  }

  @override
  Widget buildPreview(BuildContext context) {
    if (_status != CameraStatus.live) return const SizedBox.expand();
    return ColoredBox(
      color: AppColors.inkDeep,
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          size: 34,
          color: AppColors.nightLine,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    _status = CameraStatus.idle;
    _flashOn = false;
  }
}

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../domain/entities/captured_photo.dart';
import 'camera_driver.dart';

/// The real device camera, backed by the `camera` plugin.
///
/// `open()` is where Android and iOS ask for permission: the plugin surfaces
/// the answer as a [CameraException], which is mapped to [CameraStatus.denied]
/// so the capture screen can explain itself instead of showing a black box.
class PluginCameraDriver implements CameraDriver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  int _index = 0;
  CameraStatus _status = CameraStatus.idle;
  bool _flashOn = false;
  bool _hasFlash = true;

  @override
  CameraStatus get status => _status;

  @override
  bool get canFlip => _cameras.length > 1 && _status == CameraStatus.live;

  @override
  bool get hasFlash => _hasFlash && _status == CameraStatus.live;

  @override
  bool get flashOn => _flashOn;

  @override
  Future<CameraStatus> open() async {
    if (_status == CameraStatus.live || _status == CameraStatus.starting) {
      return _status;
    }
    _status = CameraStatus.starting;

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _status = CameraStatus.unavailable;
        return _status;
      }
      await _start(_preferredCamera());
      _status = CameraStatus.live;
    } on CameraException catch (error) {
      _status = _isDenied(error.code)
          ? CameraStatus.denied
          : CameraStatus.unavailable;
    } on Exception {
      _status = CameraStatus.unavailable;
    }
    return _status;
  }

  @override
  Future<void> flip() async {
    if (!canFlip) return;
    _status = CameraStatus.starting;
    _index = (_index + 1) % _cameras.length;
    try {
      await _start(_cameras[_index]);
      _status = CameraStatus.live;
    } on Exception {
      _status = CameraStatus.unavailable;
    }
  }

  @override
  Future<bool> setFlash(bool enabled) async {
    final CameraController? controller = _controller;
    if (_status != CameraStatus.live || controller == null) return false;
    try {
      await controller.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      _flashOn = enabled;
    } on Exception {
      // No torch here (web, some emulators): keep the control honest.
      _hasFlash = false;
      _flashOn = false;
    }
    return _flashOn;
  }

  @override
  Future<CapturedPhoto?> takePicture() async {
    final CameraController? controller = _controller;
    if (_status != CameraStatus.live ||
        controller == null ||
        !controller.value.isInitialized) {
      return null;
    }
    try {
      final XFile file = await controller.takePicture();
      return CapturedPhoto(
        bytes: await file.readAsBytes(),
        filename: file.name,
        contentType: 'image/jpeg',
      );
    } on Exception {
      return null;
    }
  }

  @override
  Widget buildPreview(BuildContext context) {
    final CameraController? controller = _controller;
    if (_status != CameraStatus.live ||
        controller == null ||
        !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return CameraPreview(controller);
  }

  @override
  Future<void> close() async {
    _status = CameraStatus.idle;
    final CameraController? controller = _controller;
    _controller = null;
    try {
      await controller?.dispose();
    } on Exception {
      // Already gone; nothing else to release.
    }
  }

  Future<void> _start(CameraDescription description) async {
    final CameraController? previous = _controller;
    _controller = null;
    try {
      await previous?.dispose();
    } on Exception {
      // A disposed controller has nothing left to clean up.
    }

    final CameraController controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;
    try {
      await controller.initialize();
      _flashOn = false;
    } on Exception {
      _controller = null;
      await controller.dispose();
      rethrow;
    }
  }

  CameraDescription _preferredCamera() {
    final int back = _cameras.indexWhere(
      (CameraDescription camera) =>
          camera.lensDirection == CameraLensDirection.back,
    );
    _index = back >= 0 ? back : 0;
    return _cameras[_index];
  }

  static bool _isDenied(String code) =>
      code == 'CameraAccessDenied' ||
      code == 'CameraAccessDeniedWithoutPrompt' ||
      code == 'CameraAccessRestricted';
}

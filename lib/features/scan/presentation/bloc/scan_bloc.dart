import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bills/domain/entities/bill_extraction.dart';
import '../../../bills/domain/failures/bill_failure.dart';
import '../../domain/entities/captured_photo.dart';
import '../../domain/entities/scan_source.dart';
import '../../domain/usecases/capture_bill.dart';
import '../../domain/usecases/read_photo.dart';
import '../camera/camera_driver.dart';
import 'scan_event.dart';
import 'scan_state.dart';

/// Drives the capture screen: camera access, the shutter and the trip through
/// the scanner.
///
/// The bloc owns the camera for as long as the screen lives, so permission is
/// requested from one place, the preview is released on close, and every
/// transition the page renders is a state here rather than widget-local
/// bookkeeping.
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  ScanBloc({
    required CaptureBill captureBill,
    required ReadPhoto readPhoto,
    required CameraDriver camera,
  }) : _captureBill = captureBill,
       _readPhoto = readPhoto,
       _camera = camera,
       super(const ScanIdle()) {
    on<ScanCameraRequested>(_onCameraRequested);
    on<ScanShutterPressed>(_onShutterPressed);
    on<ScanCaptureRequested>(_onCaptureRequested);
    on<ScanFlashToggled>(_onFlashToggled);
    on<ScanFlipRequested>(_onFlipRequested);
    on<ScanResetRequested>(
      (_, Emitter<ScanState> emit) => emit(_restingState()),
    );
  }

  final CaptureBill _captureBill;
  final ReadPhoto _readPhoto;
  final CameraDriver _camera;

  /// The camera this screen drives. The page needs it to draw the preview;
  /// opening and closing stay with the bloc.
  CameraDriver get camera => _camera;

  /// Shown in the frame when the camera cannot be used.
  static const String deniedMessage = 'Camera access is off';

  /// Shown in the frame when this device has no usable camera.
  static const String unavailableMessage = 'No camera available here';

  Future<void> _onCameraRequested(
    ScanCameraRequested event,
    Emitter<ScanState> emit,
  ) async {
    if (state is ScanStarting || state is ScanLive) return;

    emit(const ScanStarting());
    final CameraStatus status;
    try {
      status = await _camera.open();
    } on Exception {
      if (!isClosed) emit(const ScanBlocked(unavailableMessage));
      return;
    }
    if (isClosed) return;
    emit(_stateFor(status));
  }

  Future<void> _onShutterPressed(
    ScanShutterPressed event,
    Emitter<ScanState> emit,
  ) async {
    if (state is ScanScanning) return;

    emit(const ScanScanning(ScanSource.camera));
    CapturedPhoto? photo;
    try {
      photo = await _camera.takePicture();
    } on Exception {
      photo = null;
    }
    if (isClosed) return;

    if (photo == null) {
      emit(const ScanFailure('Could not take that photo. Try again.'));
      return;
    }
    await _readAndEmit(photo, emit);
  }

  Future<void> _onCaptureRequested(
    ScanCaptureRequested event,
    Emitter<ScanState> emit,
  ) async {
    if (state is ScanScanning) return;

    emit(ScanScanning(event.source));
    try {
      final BillExtraction? report = await _captureBill(event.source);
      if (isClosed) return;
      // The picker was dismissed: quietly return to the prompt.
      emit(report == null ? _restingState() : ScanCaptured(report));
    } on BillFailure catch (failure) {
      if (!isClosed) emit(ScanFailure(failure.message));
    } on Exception {
      if (!isClosed) {
        emit(const ScanFailure('Could not read that bill. Try once more.'));
      }
    }
  }

  Future<void> _onFlashToggled(
    ScanFlashToggled event,
    Emitter<ScanState> emit,
  ) async {
    final ScanState current = state;
    if (current is! ScanLive) return;

    final bool on = await _camera.setFlash(!current.flashOn);
    if (isClosed) return;
    emit(ScanLive(flashOn: on));
  }

  Future<void> _onFlipRequested(
    ScanFlipRequested event,
    Emitter<ScanState> emit,
  ) async {
    if (state is! ScanLive || !_camera.canFlip) return;

    emit(const ScanStarting());
    try {
      await _camera.flip();
    } on Exception {
      if (!isClosed) emit(const ScanBlocked(unavailableMessage));
      return;
    }
    if (isClosed) return;
    emit(_stateFor(_camera.status));
  }

  /// Sends an already-captured photo through the scanner while [ScanScanning]
  /// holds, which is what the page's loader is attached to.
  Future<void> _readAndEmit(
    CapturedPhoto photo,
    Emitter<ScanState> emit,
  ) async {
    try {
      final BillExtraction report = await _readPhoto(photo);
      if (isClosed) return;
      emit(ScanCaptured(report));
    } on BillFailure catch (failure) {
      if (!isClosed) emit(ScanFailure(failure.message));
    } on Exception {
      if (!isClosed) {
        emit(const ScanFailure('Could not read that bill. Try once more.'));
      }
    }
  }

  /// What the screen looks like when nothing is in flight.
  ScanState _restingState() => _stateFor(_camera.status);

  ScanState _stateFor(CameraStatus status) => switch (status) {
    CameraStatus.live => const ScanLive(),
    CameraStatus.starting => const ScanStarting(),
    CameraStatus.denied => const ScanBlocked(deniedMessage),
    CameraStatus.unavailable => const ScanBlocked(unavailableMessage),
    CameraStatus.idle => const ScanIdle(),
  };

  @override
  Future<void> close() async {
    try {
      await _camera.close();
    } on Exception {
      // The camera is gone either way; nothing else to release.
    }
    return super.close();
  }
}

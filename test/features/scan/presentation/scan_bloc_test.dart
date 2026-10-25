import 'dart:async';

import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/failures/bill_failure.dart';
import 'package:bill_scanner/features/scan/domain/entities/captured_photo.dart';
import 'package:bill_scanner/features/scan/domain/entities/scan_source.dart';
import 'package:bill_scanner/features/scan/domain/repositories/scan_repository.dart';
import 'package:bill_scanner/features/scan/domain/usecases/capture_bill.dart';
import 'package:bill_scanner/features/scan/domain/usecases/read_photo.dart';
import 'package:bill_scanner/features/scan/presentation/bloc/scan_bloc.dart';
import 'package:bill_scanner/features/scan/presentation/bloc/scan_event.dart';
import 'package:bill_scanner/features/scan/presentation/bloc/scan_state.dart';
import 'package:bill_scanner/features/scan/presentation/camera/camera_driver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The camera as the bloc sees it: every call is recorded, nothing touches a
/// device.
class _FakeCamera implements CameraDriver {
  _FakeCamera({
    this.statusOnOpen = CameraStatus.live,
    this.latency = Duration.zero,
    this.takeFails = false,
  });

  /// What `open()` reports.
  final CameraStatus statusOnOpen;

  /// Delay inside `open()`, long enough for the starting state to be seen.
  final Duration latency;

  final bool takeFails;

  CameraStatus _status = CameraStatus.idle;
  bool _flashOn = false;
  int opens = 0;
  int closes = 0;
  int flips = 0;
  int flashes = 0;
  int takes = 0;

  @override
  CameraStatus get status => _status;

  @override
  bool get canFlip => _status == CameraStatus.live;

  @override
  bool get hasFlash => _status == CameraStatus.live;

  @override
  bool get flashOn => _flashOn;

  @override
  Future<CameraStatus> open() async {
    opens += 1;
    if (latency > Duration.zero) {
      await Future<void>.delayed(latency);
    }
    _status = statusOnOpen;
    return _status;
  }

  @override
  Future<void> flip() async {
    flips += 1;
  }

  @override
  Future<bool> setFlash(bool enabled) async {
    flashes += 1;
    _flashOn = enabled;
    return _flashOn;
  }

  @override
  Future<CapturedPhoto?> takePicture() async {
    takes += 1;
    if (takeFails) return null;
    return const CapturedPhoto(bytes: <int>[1, 2], filename: 'shot.jpg');
  }

  @override
  Widget buildPreview(BuildContext context) => const SizedBox();

  @override
  Future<void> close() async {
    closes += 1;
    _status = CameraStatus.idle;
  }
}

class _FakeScanRepository implements ScanRepository {
  _FakeScanRepository({this.readLatency = Duration.zero, this.failure});

  final Duration readLatency;
  final BillFailure? failure;

  int reads = 0;
  CapturedPhoto? lastRead;
  ScanSource? lastPick;

  Bill get _bill => Bill(
    id: 'b1',
    merchant: 'Asha Tiffins',
    date: DateTime(2026, 10, 25),
    total: 120,
    category: BillCategory.foodAndDrink,
    items: const <BillItem>[BillItem(name: 'Thali', amount: 120)],
  );

  @override
  Future<BillExtraction> read(CapturedPhoto photo) async {
    if (readLatency > Duration.zero) {
      await Future<void>.delayed(readLatency);
    }
    reads += 1;
    lastRead = photo;
    if (failure != null) throw failure!;
    return BillExtraction(bill: _bill);
  }

  @override
  Future<BillExtraction?> capture(ScanSource source) async {
    lastPick = source;
    if (failure != null) throw failure!;
    return BillExtraction(bill: _bill);
  }

  @override
  Bill get sampleBill => _bill;
}

ScanBloc _bloc(ScanRepository repository, CameraDriver camera) => ScanBloc(
  captureBill: CaptureBill(repository),
  readPhoto: ReadPhoto(repository),
  camera: camera,
);

void main() {
  test('camera access walks idle, starting and live', () async {
    final _FakeCamera camera = _FakeCamera(
      latency: const Duration(milliseconds: 20),
    );
    final ScanBloc bloc = _bloc(_FakeScanRepository(), camera);
    final List<ScanState> states = <ScanState>[];
    final StreamSubscription<ScanState> sub = bloc.stream.listen(states.add);

    expect(bloc.state, const ScanIdle());

    bloc.add(const ScanCameraRequested());
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(states, <ScanState>[const ScanStarting(), const ScanLive()]);
    expect(camera.opens, 1);

    bloc.add(const ScanResetRequested());
    await pumpEventQueue();
    expect(bloc.state, const ScanLive());

    await sub.cancel();
    await bloc.close();
    expect(camera.closes, 1);
  });

  test('a refused permission lands on the blocked state', () async {
    final _FakeCamera camera = _FakeCamera(statusOnOpen: CameraStatus.denied);
    final ScanBloc bloc = _bloc(_FakeScanRepository(), camera);
    final List<ScanState> states = <ScanState>[];
    final StreamSubscription<ScanState> sub = bloc.stream.listen(states.add);

    bloc.add(const ScanCameraRequested());
    await pumpEventQueue();

    expect(states, <ScanState>[
      const ScanStarting(),
      const ScanBlocked(ScanBloc.deniedMessage),
    ]);

    // The retry asks again instead of giving up.
    bloc.add(const ScanCameraRequested());
    await pumpEventQueue();
    expect(camera.opens, 2);

    await sub.cancel();
    await bloc.close();
  });

  test('the shutter shows the loader while the scanner reads', () async {
    final _FakeCamera camera = _FakeCamera();
    final _FakeScanRepository repository = _FakeScanRepository(
      readLatency: const Duration(milliseconds: 40),
    );
    final ScanBloc bloc = _bloc(repository, camera);
    final List<ScanState> states = <ScanState>[];
    final StreamSubscription<ScanState> sub = bloc.stream.listen(states.add);

    bloc.add(const ScanCameraRequested());
    await pumpEventQueue();
    states.clear();

    bloc.add(const ScanShutterPressed());
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(bloc.state, const ScanScanning(ScanSource.camera));
    expect(repository.reads, 0);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(states, <Object>[
      const ScanScanning(ScanSource.camera),
      isA<ScanCaptured>(),
    ]);
    expect(repository.reads, 1);
    expect(repository.lastRead?.filename, 'shot.jpg');
    expect(camera.takes, 1);

    await sub.cancel();
    await bloc.close();
  });

  test('a scanner failure surfaces a readable message', () async {
    final ScanBloc bloc = _bloc(
      _FakeScanRepository(failure: const BillFailure('That photo is too big.')),
      _FakeCamera(),
    );
    final List<ScanState> states = <ScanState>[];
    final StreamSubscription<ScanState> sub = bloc.stream.listen(states.add);

    bloc.add(const ScanCameraRequested());
    await pumpEventQueue();
    states.clear();

    bloc.add(const ScanShutterPressed());
    await pumpEventQueue();

    expect(states, <ScanState>[
      const ScanScanning(ScanSource.camera),
      const ScanFailure('That photo is too big.'),
    ]);

    await sub.cancel();
    await bloc.close();
  });

  test('a shutter press with no picture is a retryable failure', () async {
    final ScanBloc bloc = _bloc(
      _FakeScanRepository(),
      _FakeCamera(takeFails: true),
    );
    final List<ScanState> states = <ScanState>[];
    final StreamSubscription<ScanState> sub = bloc.stream.listen(states.add);

    bloc.add(const ScanCameraRequested());
    await pumpEventQueue();
    states.clear();

    bloc.add(const ScanShutterPressed());
    await pumpEventQueue();

    expect(states, <ScanState>[
      const ScanScanning(ScanSource.camera),
      const ScanFailure('Could not take that photo. Try again.'),
    ]);

    await sub.cancel();
    await bloc.close();
  });

  test('flash and flip only run while the preview is live', () async {
    final _FakeCamera camera = _FakeCamera();
    final ScanBloc bloc = _bloc(_FakeScanRepository(), camera);
    final List<ScanState> states = <ScanState>[];
    final StreamSubscription<ScanState> sub = bloc.stream.listen(states.add);

    bloc.add(const ScanFlashToggled());
    bloc.add(const ScanFlipRequested());
    await pumpEventQueue();
    expect(states, isEmpty);
    expect(camera.flashes, 0);
    expect(camera.flips, 0);

    bloc.add(const ScanCameraRequested());
    await pumpEventQueue();
    states.clear();

    bloc.add(const ScanFlashToggled());
    await pumpEventQueue();
    expect(bloc.state, const ScanLive(flashOn: true));
    expect(camera.flashes, 1);

    bloc.add(const ScanFlipRequested());
    await pumpEventQueue();
    expect(camera.flips, 1);
    expect(bloc.state, const ScanLive());

    await sub.cancel();
    await bloc.close();
  });
}

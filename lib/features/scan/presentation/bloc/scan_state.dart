import 'package:equatable/equatable.dart';

import '../../../bills/domain/entities/bill_extraction.dart';
import '../../domain/entities/scan_source.dart';

/// States of the capture screen.
///
/// One sealed class per feature: the page renders a switch over these, so a
/// missing case is a compile error rather than a blank screen.
sealed class ScanState extends Equatable {
  const ScanState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Waiting on the person: the gallery prompt, or the camera screen before
/// access has been asked for.
final class ScanIdle extends ScanState {
  const ScanIdle();
}

/// Permission is being requested, the preview is starting up, or the lens is
/// being switched. The shutter is not available yet.
final class ScanStarting extends ScanState {
  const ScanStarting();
}

/// The preview is running: the shutter, flash and flip controls are live.
final class ScanLive extends ScanState {
  const ScanLive({this.flashOn = false});

  /// Mirrors the torch so the top bar icon rebuilds with the state.
  final bool flashOn;

  @override
  List<Object?> get props => <Object?>[flashOn];
}

/// The camera could not be used: permission refused, or no camera here.
///
/// The page renders [message] inside the frame and keeps an "Allow camera"
/// retry in the sheet.
final class ScanBlocked extends ScanState {
  const ScanBlocked(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// The photo is on its way through the scanner: the loader state.
///
/// [source] says which path is running - the shutter or the library picker -
/// so the copy under the loader can differ.
final class ScanScanning extends ScanState {
  const ScanScanning(this.source);

  final ScanSource source;

  @override
  List<Object?> get props => <Object?>[source];
}

/// The scanner produced a draft and the fields its checks flagged.
final class ScanCaptured extends ScanState {
  const ScanCaptured(this.report);

  final BillExtraction report;

  @override
  List<Object?> get props => <Object?>[report];
}

/// Something went wrong; the page shows it and resets to the resting state.
final class ScanFailure extends ScanState {
  const ScanFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

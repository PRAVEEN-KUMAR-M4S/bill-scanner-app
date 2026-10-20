import 'package:equatable/equatable.dart';

import '../../../bills/domain/entities/bill.dart';

sealed class ScanState extends Equatable {
  const ScanState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Waiting on camera permission (step 01 of the capture sheet).
final class ScanIdle extends ScanState {
  const ScanIdle();
}

/// The photo is being read.
final class ScanScanning extends ScanState {
  const ScanScanning();
}

/// The scanner produced a bill for review.
final class ScanCaptured extends ScanState {
  const ScanCaptured(this.bill);

  final Bill bill;

  @override
  List<Object?> get props => <Object?>[bill];
}

final class ScanFailure extends ScanState {
  const ScanFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

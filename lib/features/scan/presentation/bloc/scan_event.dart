import 'package:equatable/equatable.dart';

sealed class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The camera was granted; capture and read the bill.
final class ScanCameraAllowed extends ScanEvent {
  const ScanCameraAllowed();
}

/// Clear the failure and return to the permission prompt.
final class ScanResetRequested extends ScanEvent {
  const ScanResetRequested();
}

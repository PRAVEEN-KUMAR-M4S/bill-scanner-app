import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bills/domain/entities/bill.dart';
import '../../domain/usecases/capture_bill.dart';
import 'scan_event.dart';
import 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  ScanBloc({required CaptureBill captureBill})
    : _captureBill = captureBill,
      super(const ScanIdle()) {
    on<ScanCameraAllowed>(_onCameraAllowed);
    on<ScanResetRequested>((_, Emitter<ScanState> emit) {
      emit(const ScanIdle());
    });
  }

  final CaptureBill _captureBill;

  Future<void> _onCameraAllowed(
    ScanCameraAllowed event,
    Emitter<ScanState> emit,
  ) async {
    if (state is ScanScanning) return;

    emit(const ScanScanning());
    try {
      final Bill bill = await _captureBill();
      emit(ScanCaptured(bill));
    } on Exception {
      emit(const ScanFailure('Could not read that bill. Try once more.'));
    }
  }
}

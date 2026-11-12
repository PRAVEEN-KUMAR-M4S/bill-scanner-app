import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/load_balance.dart';
import '../../domain/usecases/update_balance.dart';
import 'balance_event.dart';
import 'balance_state.dart';

/// One sealed event/state pair for the balance card.
///
/// The bloc holds the *entry* the user made; what the dashboard displays is
/// that entry minus the bills, and the bills arrive through `BillsBloc`. So
/// saving a bill does not send this bloc an event — the card recomputes from
/// both sources when `BillsBloc` emits.
class BalanceBloc extends Bloc<BalanceEvent, BalanceState> {
  BalanceBloc({
    required LoadBalance loadBalance,
    required UpdateBalance updateBalance,
  }) : _loadBalance = loadBalance,
       _updateBalance = updateBalance,
       super(const BalanceLoading()) {
    on<BalanceStarted>(_onStarted);
    on<BalanceBaseUpdated>(_onBaseUpdated);
  }

  final LoadBalance _loadBalance;
  final UpdateBalance _updateBalance;

  Future<void> _onStarted(
    BalanceStarted event,
    Emitter<BalanceState> emit,
  ) async {
    emit(const BalanceLoading());
    await _read(emit);
  }

  Future<void> _onBaseUpdated(
    BalanceBaseUpdated event,
    Emitter<BalanceState> emit,
  ) async {
    try {
      await _updateBalance(event.base);
      // Read back rather than trusting the event: the repository decides what
      // was actually stored (and on a platform with no database it keeps the
      // value in memory), so the card never shows a figure that was not saved.
      await _read(emit);
    } on Exception {
      emit(const BalanceFailure('Could not save your balance. Try again.'));
    }
  }

  Future<void> _read(Emitter<BalanceState> emit) async {
    try {
      emit(BalanceLoaded(await _loadBalance()));
    } on Exception {
      emit(const BalanceFailure('Could not read your balance. Try again.'));
    }
  }
}

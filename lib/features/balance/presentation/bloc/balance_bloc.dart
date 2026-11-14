import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/failures/balance_exception.dart';
import '../../domain/usecases/load_balance.dart';
import '../../domain/usecases/update_balance.dart';
import 'balance_event.dart';
import 'balance_state.dart';

/// One sealed event/state pair for the balance card.
///
/// The bloc holds the account's figure; what the card displays is that figure
/// minus the spending, and the spending arrives with the balance for a
/// signed-in account (the API counts it) or from the bills for a guest.
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
      // The repository answers with what was stored, so nothing is read back.
      emit(BalanceLoaded(await _updateBalance(event.base)));
    } on BalanceException catch (exception) {
      emit(BalanceFailure(exception.message));
    } on Exception {
      emit(const BalanceFailure('Could not save your balance. Try again.'));
    }
  }

  Future<void> _read(Emitter<BalanceState> emit) async {
    try {
      emit(BalanceLoaded(await _loadBalance()));
    } on BalanceException catch (exception) {
      emit(BalanceFailure(exception.message));
    } on Exception {
      emit(const BalanceFailure('Could not read your balance. Try again.'));
    }
  }
}

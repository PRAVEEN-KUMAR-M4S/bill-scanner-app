import 'package:equatable/equatable.dart';

import '../../domain/entities/balance.dart';

sealed class BalanceState extends Equatable {
  const BalanceState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Reading the stored figure.
final class BalanceLoading extends BalanceState {
  const BalanceLoading();
}

/// The stored figure. The card subtracts the bills from
/// [Balance.base] to get what it shows.
final class BalanceLoaded extends BalanceState {
  const BalanceLoaded(this.balance);

  final Balance balance;

  @override
  List<Object?> get props => <Object?>[balance];
}

/// The database could not be read or written; [message] is user-facing.
final class BalanceFailure extends BalanceState {
  const BalanceFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

import 'package:equatable/equatable.dart';

sealed class BalanceEvent extends Equatable {
  const BalanceEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

/// The shell is showing the dashboard: read the stored figure.
final class BalanceStarted extends BalanceEvent {
  const BalanceStarted();
}

/// The user saved a new figure on the card's "Update" sheet.
final class BalanceBaseUpdated extends BalanceEvent {
  const BalanceBaseUpdated(this.base);

  final double base;

  @override
  List<Object?> get props => <Object?>[base];
}

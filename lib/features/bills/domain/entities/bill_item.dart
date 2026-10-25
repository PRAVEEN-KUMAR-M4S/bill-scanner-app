import 'package:equatable/equatable.dart';

/// One printed line of a bill.
///
/// [amount] is the money charged for the whole line — the printed Amount
/// column, after discount and including tax. It is never a unit rate and is
/// never multiplied by [quantity]; the backend's checks rely on that meaning.
class BillItem extends Equatable {
  const BillItem({required this.name, required this.amount, this.quantity});

  final String name;

  /// Money for the whole line, in rupees with two decimals.
  final double amount;

  /// Printed quantity when the bill shows one; informational only.
  final int? quantity;

  /// The amount this line contributes to the bill total.
  double get lineTotal => amount;

  @override
  List<Object?> get props => <Object?>[name, amount, quantity];
}

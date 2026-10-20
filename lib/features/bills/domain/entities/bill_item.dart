import 'package:equatable/equatable.dart';

/// One line of a bill: a name, how many, and the price of a single unit.
class BillItem extends Equatable {
  const BillItem({
    required this.name,
    required this.quantity,
    required this.priceEach,
  });

  final String name;
  final int quantity;
  final double priceEach;

  /// `quantity × priceEach`, the amount this line contributes to the bill.
  double get lineTotal => quantity * priceEach;

  @override
  List<Object?> get props => <Object?>[name, quantity, priceEach];
}

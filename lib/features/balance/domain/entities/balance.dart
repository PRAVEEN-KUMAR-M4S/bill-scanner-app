import 'package:equatable/equatable.dart';

import '../../../bills/domain/entities/bill.dart';

/// The account balance the dashboard keeps track of.
///
/// Two numbers, one rule:
/// - [base] is what the user typed in on the "Update" sheet. It is their own
///   entry — nothing syncs it from a bank.
/// - [available] is [base] minus every bill saved for the account. Each new
///   expense moves it, which is the whole point of showing it next to the
///   spend card.
///
/// Bills are subtracted whichever way they are stored: a bill still waiting in
/// the upload queue is money already spent, so `pending` rows count too.
class Balance extends Equatable {
  const Balance({required this.base, this.updatedAt});

  /// Value offered the first time an account opens the dashboard, before it
  /// has entered its own figure. A placeholder the user replaces with
  /// "Update", not a balance the app knows about.
  static const double defaultBase = 25000;

  final double base;

  /// When [base] was last written, straight from the database row. The card
  /// does not show it yet; it exists so a later "last updated" hint has a
  /// source.
  final DateTime? updatedAt;

  /// The figure on the card: the entry minus every bill, newest or oldest,
  /// synced or pending.
  double available(Iterable<Bill> bills) {
    double spent = 0;
    for (final Bill bill in bills) {
      spent += bill.total;
    }
    return base - spent;
  }

  Balance copyWith({double? base, DateTime? updatedAt}) {
    return Balance(
      base: base ?? this.base,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[base, updatedAt];
}

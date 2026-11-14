import 'package:equatable/equatable.dart';

import '../../../bills/domain/entities/bill.dart';

/// The account balance the dashboard keeps track of.
///
/// Two numbers, one rule:
/// - [base] is the money available: the figure the user set on the "Update"
///   sheet, which the API stores as the opening balance.
/// - [available] is [base] minus what has been spent.
///
/// Whoever counts the spending decides where it comes from:
/// - a signed-in account gets [spent] from the API, which counts every bill it
///   has stored;
/// - a guest, or a cached figure read while offline, has no [spent] and the
///   bills already on the phone are subtracted instead. A bill still waiting in
///   the upload queue is money already spent, so `pending` rows count too.
class Balance extends Equatable {
  const Balance({
    required this.base,
    this.spent,
    this.currency = 'INR',
    this.updatedAt,
  });

  /// Value offered the first time a guest opens the dashboard, before it has
  /// entered its own figure. A placeholder the user replaces with "Update"; an
  /// account always gets its real figure from the API.
  static const double defaultBase = 25000;

  final double base;

  /// Everything spent through the app, as the API counts it. `null` when the
  /// figure is not server-backed.
  final double? spent;

  /// ISO code the API reports; the card formats everything as INR today.
  final String currency;

  /// When [base] was last written, straight from the database row. The card
  /// does not show it yet; it exists so a later "last updated" hint has a
  /// source.
  final DateTime? updatedAt;

  /// The figure on the card.
  double available(Iterable<Bill> bills) {
    final double? serverSpent = spent;
    if (serverSpent != null) return base - serverSpent;

    double localSpent = 0;
    for (final Bill bill in bills) {
      localSpent += bill.total;
    }
    return base - localSpent;
  }

  Balance copyWith({double? base, String? currency, DateTime? updatedAt}) {
    return Balance(
      base: base ?? this.base,
      spent: spent,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[base, spent, currency, updatedAt];
}

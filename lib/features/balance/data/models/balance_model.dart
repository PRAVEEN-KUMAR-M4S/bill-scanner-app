import '../../../../core/network/api_exception.dart';
import '../../domain/entities/balance.dart';

/// The `/account` and `/account/balance` payload, mapped to [Balance].
///
/// The API sends the amounts as strings (`"5000000.00"`), so each one is parsed
/// rather than cast. A missing or unreadable `balance` is a broken response,
/// which the shared [ApiFormatException] reports.
class BalanceModel {
  const BalanceModel._();

  static Balance fromJson(Map<String, dynamic> json) {
    final double? balance = _amount(json['balance']);
    if (balance == null) throw const ApiFormatException();

    return Balance(
      base: balance,
      spent: _amount(json['spent']),
      currency: switch (json['currency']) {
        final String code when code.isNotEmpty => code,
        _ => 'INR',
      },
    );
  }

  static double? _amount(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}

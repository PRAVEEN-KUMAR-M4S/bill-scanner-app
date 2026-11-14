import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/entities/balance.dart';
import '../../domain/failures/balance_exception.dart';
import '../models/balance_model.dart';

/// The two account endpoints of the Bill Reader API.
///
/// `GET /account` reads the balance and everything spent; `PUT
/// /account/balance` replaces the balance (it never adds to it). The only
/// balance file that knows paths and JSON field names, and the only one that
/// knows status codes: every failure leaves here as a [BalanceException] whose
/// message is ready for the card.
class AccountRemoteDataSource {
  const AccountRemoteDataSource(this._api);

  final ApiService _api;

  /// The current balance and the spend total the API tracks.
  Future<Balance> fetch() async {
    try {
      final Object? json = await _api.get(
        ApiEndpoints.account,
        authenticated: true,
      );
      return BalanceModel.fromJson(_asMap(json));
    } on ApiException catch (exception) {
      throw _failureFor(exception);
    }
  }

  /// Replaces the stored figure: "I have 5,000", not "add 5,000".
  Future<Balance> setBalance(double balance) async {
    try {
      final Object? json = await _api.put(
        ApiEndpoints.accountBalance,
        body: <String, Object?>{'balance': balance},
        authenticated: true,
      );
      return BalanceModel.fromJson(_asMap(json));
    } on ApiException catch (exception) {
      throw _failureFor(exception);
    }
  }

  BalanceException _failureFor(ApiException exception) {
    if (exception is UnauthorizedApiException) {
      return const BalanceException(
        'Your session expired. Please sign in again.',
      );
    }

    if (exception is ValidationApiException) {
      return BalanceException(
        exception.fields['balance'] ?? 'That amount is not valid.',
      );
    }

    if (exception is NetworkApiException || exception is TimeoutApiException) {
      return const BalanceException.offline(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (exception is RateLimitedApiException) {
      return const BalanceException(
        'Too many requests. Try again in a minute.',
      );
    }

    if (exception is ApiFormatException) {
      return const BalanceException(
        'The server sent an unexpected response.',
      );
    }

    return const BalanceException('Could not update your balance. Try again.');
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (Object? key, Object? entry) => MapEntry(key.toString(), entry),
      );
    }
    throw const ApiFormatException();
  }
}

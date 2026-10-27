import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../../domain/failures/auth_failure.dart';
import '../models/auth_tokens.dart';
import '../models/user_model.dart';

/// The five auth endpoints exposed by the Bill Reader API.
///
/// The only place that knows their URLs and JSON field names, and the only
/// place that knows HTTP status codes: every [ApiException] leaves here as an
/// [AuthFailure] whose message is safe to put in front of the user. The
/// repository and the UI therefore never branch on a status code.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._api);

  final ApiService _api;

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    try {
      final Object? json = await _api.post(
        ApiEndpoints.authLogin,
        body: <String, Object?>{'email': email, 'password': password},
      );
      return AuthTokens.fromJson(_asMap(json));
    } on ApiException catch (exception) {
      throw _failureFor(exception, submittingCredentials: true);
    }
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.authRegister,
        body: <String, Object?>{'email': email, 'password': password},
      );
    } on ApiException catch (exception) {
      throw _failureFor(exception, submittingCredentials: true);
    }
  }

  /// The signed-in account, using the access token held by [ApiService].
  Future<UserModel> me() async {
    try {
      final Object? json = await _api.get(
        ApiEndpoints.authMe,
        authenticated: true,
      );
      return UserModel.fromJson(_asMap(json));
    } on ApiException catch (exception) {
      throw _failureFor(exception, submittingCredentials: false);
    }
  }

  /// Trades a refresh token for a new pair. The old token is single-use.
  Future<AuthTokens> refresh(String refreshToken) async {
    try {
      final Object? json = await _api.post(
        ApiEndpoints.authRefresh,
        body: <String, Object?>{'refresh_token': refreshToken},
      );
      return AuthTokens.fromJson(_asMap(json));
    } on ApiException catch (exception) {
      throw _failureFor(exception, submittingCredentials: false);
    }
  }

  /// Revokes one session. The endpoint answers 204 with no body.
  Future<void> logout(String refreshToken) async {
    try {
      await _api.post(
        ApiEndpoints.authLogout,
        body: <String, Object?>{'refresh_token': refreshToken},
      );
    } on ApiException catch (exception) {
      throw _failureFor(exception, submittingCredentials: false);
    }
  }

  /// [submittingCredentials] is what decides how a 401 reads: the person typed
  /// the wrong password, or the stored session is no longer accepted.
  AuthFailure _failureFor(
    ApiException exception, {
    required bool submittingCredentials,
  }) {
    if (exception is UnauthorizedApiException) {
      return AuthFailure(
        submittingCredentials
            ? 'Email or password is incorrect.'
            : 'Your session expired. Please sign in again.',
      );
    }

    if (_isDuplicateAccount(exception)) {
      return const AuthFailure(
        'That email is already registered. Try signing in.',
      );
    }

    if (exception is ValidationApiException) {
      return AuthFailure(
        exception.fields['password'] ??
            exception.fields['email'] ??
            exception.message,
      );
    }

    if (exception is NetworkApiException || exception is TimeoutApiException) {
      return const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (exception is RateLimitedApiException) {
      return const AuthFailure('Too many attempts. Try again in a minute.');
    }

    if (exception is ApiFormatException) {
      return const AuthFailure('The server sent an unexpected response.');
    }

    return const AuthFailure('Something went wrong. Please try again.');
  }

  /// The API reports an existing account either as a 409 or as a 400 whose body
  /// says so.
  bool _isDuplicateAccount(ApiException exception) {
    if (exception is ConflictApiException) return true;
    if (exception is! BadRequestApiException) return false;

    final String text = exception.body?.toLowerCase() ?? '';
    return text.contains('already') ||
        text.contains('exists') ||
        text.contains('registered');
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

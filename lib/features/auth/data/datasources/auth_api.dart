import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_service.dart';
import '../models/api_user.dart';
import '../models/auth_tokens.dart';

/// The five auth endpoints exposed by the Bill Reader API.
///
/// This is the only place that knows their URLs and JSON field names; the
/// repository above it speaks in [AuthTokens] and [ApiUser], and the domain
/// only sees its own `AppUser`.
class AuthApi {
  const AuthApi(this._api);

  final ApiService _api;

  Future<AuthTokens> login({
    required String email,
    required String password,
  }) async {
    final Object? json = await _api.post(
      ApiEndpoints.authLogin,
      body: <String, Object?>{'email': email, 'password': password},
    );
    return AuthTokens.fromJson(_asMap(json));
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    await _api.post(
      ApiEndpoints.authRegister,
      body: <String, Object?>{'email': email, 'password': password},
    );
  }

  /// The signed-in account, using the access token held by [ApiService].
  Future<ApiUser> me() async {
    final Object? json = await _api.get(
      ApiEndpoints.authMe,
      authenticated: true,
    );
    return ApiUser.fromJson(_asMap(json));
  }

  /// Trades a refresh token for a new pair. The old token is single-use.
  Future<AuthTokens> refresh(String refreshToken) async {
    final Object? json = await _api.post(
      ApiEndpoints.authRefresh,
      body: <String, Object?>{'refresh_token': refreshToken},
    );
    return AuthTokens.fromJson(_asMap(json));
  }

  /// Revokes one session. The endpoint answers 204 with no body.
  Future<void> logout(String refreshToken) async {
    await _api.post(
      ApiEndpoints.authLogout,
      body: <String, Object?>{'refresh_token': refreshToken},
    );
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

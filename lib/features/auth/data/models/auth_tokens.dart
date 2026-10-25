import '../../../../core/network/api_exception.dart';

/// The pair the API issues on login and rotates on refresh.
class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final Object? access = json['access_token'];
    final Object? refresh = json['refresh_token'];
    if (access is! String ||
        refresh is! String ||
        access.isEmpty ||
        refresh.isEmpty) {
      throw const ApiFormatException();
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  final String accessToken;
  final String refreshToken;
}

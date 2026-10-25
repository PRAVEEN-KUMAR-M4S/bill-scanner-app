import '../../../../core/network/api_exception.dart';

/// The account shape returned by `GET /auth/me`.
///
/// The backend stores an id and an email only; the display name is a UI
/// concern derived in [ApiAuthRepository].
class ApiUser {
  const ApiUser({required this.id, required this.email});

  factory ApiUser.fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? email = json['email'];
    if (id == null || email is! String || email.isEmpty) {
      throw const ApiFormatException();
    }
    return ApiUser(id: id.toString(), email: email);
  }

  final String id;
  final String email;
}

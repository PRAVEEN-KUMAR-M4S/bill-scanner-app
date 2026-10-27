import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Signs in with an email and a password.
///
/// The repository stores the session, so a caller only has to react to the
/// returned [User] or to the `AuthFailure` the request raises.
class Login {
  const Login(this._repository);

  final AuthRepository _repository;

  Future<User> call({required String email, required String password}) {
    return _repository.signIn(email: email, password: password);
  }
}

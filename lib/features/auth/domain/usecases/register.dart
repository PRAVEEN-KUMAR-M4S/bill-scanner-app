import '../entities/user.dart';
import '../repositories/auth_repository.dart';

/// Creates an account and signs it in.
///
/// The name is remembered for the new session, because the API stores an email
/// only; later sign-ins derive a display name from the email instead.
class Register {
  const Register(this._repository);

  final AuthRepository _repository;

  Future<User> call({
    required String name,
    required String email,
    required String password,
  }) {
    return _repository.register(name: name, email: email, password: password);
  }
}

import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class RegisterAccount {
  const RegisterAccount(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call({
    required String name,
    required String email,
    required String password,
  }) {
    return _repository.register(name: name, email: email, password: password);
  }
}

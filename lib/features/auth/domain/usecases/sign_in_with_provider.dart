import '../entities/user.dart';
import '../entities/auth_provider.dart';
import '../repositories/auth_repository.dart';

class SignInWithProvider {
  const SignInWithProvider(this._repository);

  final AuthRepository _repository;

  Future<User> call(AuthProvider provider) {
    return _repository.signInWithProvider(provider);
  }
}

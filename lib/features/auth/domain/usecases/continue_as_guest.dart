import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class ContinueAsGuest {
  const ContinueAsGuest(this._repository);

  final AuthRepository _repository;

  Future<User> call() => _repository.continueAsGuest();
}

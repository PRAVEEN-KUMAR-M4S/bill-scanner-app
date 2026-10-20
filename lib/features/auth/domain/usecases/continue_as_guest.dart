import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class ContinueAsGuest {
  const ContinueAsGuest(this._repository);

  final AuthRepository _repository;

  Future<AppUser> call() => _repository.continueAsGuest();
}

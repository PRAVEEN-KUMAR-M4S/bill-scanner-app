import '../repositories/auth_repository.dart';

/// Ends the session. Implementations revoke server-side tokens when they can,
/// but the local session is always cleared.
class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<void> call() => _repository.signOut();
}

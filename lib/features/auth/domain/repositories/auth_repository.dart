import '../entities/app_user.dart';
import '../entities/auth_provider.dart';

/// Contract for authentication, fulfilled by the data layer.
abstract interface class AuthRepository {
  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> signInWithProvider(AuthProvider provider);

  Future<AppUser> continueAsGuest();
}

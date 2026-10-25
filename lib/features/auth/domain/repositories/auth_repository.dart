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

  /// The account saved on this device, or `null` when nobody is signed in.
  Future<AppUser?> restoreSession();

  /// Ends the session locally and, when the backend is involved, revokes it.
  Future<void> signOut();
}

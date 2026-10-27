import '../entities/user.dart';
import '../entities/auth_provider.dart';

/// Contract for authentication, fulfilled by the data layer.
abstract interface class AuthRepository {
  Future<User> signIn({required String email, required String password});

  Future<User> register({
    required String name,
    required String email,
    required String password,
  });

  Future<User> signInWithProvider(AuthProvider provider);

  Future<User> continueAsGuest();

  /// The account saved on this device, or `null` when nobody is signed in.
  Future<User?> restoreSession();

  /// Ends the session locally and, when the backend is involved, revokes it.
  Future<void> signOut();
}

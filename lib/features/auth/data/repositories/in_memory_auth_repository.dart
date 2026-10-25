import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_provider.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

/// In-memory stand-in for the future account backend.
///
/// Enforces the same rules the real API will, so the presentation layer can be
/// built and tested against realistic states (including failures).
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({this.latency = const Duration(milliseconds: 700)});

  /// Simulated round-trip time.
  final Duration latency;

  final Set<String> _registeredEmails = <String>{};

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    _ensurePasswordIsStrong(password);
    return AppUser(
      id: email.trim().toLowerCase(),
      name: _displayNameFromEmail(email),
      email: email.trim(),
    );
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    _ensurePasswordIsStrong(password);
    if (!_registeredEmails.add(email.trim().toLowerCase())) {
      throw const AuthFailure(
        'That email is already registered. Try signing in.',
      );
    }
    return AppUser(
      id: email.trim().toLowerCase(),
      name: name.trim(),
      email: email.trim(),
    );
  }

  @override
  Future<AppUser> signInWithProvider(AuthProvider provider) async {
    await Future<void>.delayed(latency);
    return AppUser(
      id: '${provider.name}-demo',
      name: '${_capitalize(provider.name)} User',
      email: 'you@${provider.name}.com',
    );
  }

  @override
  Future<AppUser> continueAsGuest() async {
    await Future<void>.delayed(latency);
    return const AppUser(id: 'guest', name: 'Guest', email: '', isGuest: true);
  }

  @override
  Future<AppUser?> restoreSession() async {
    // The in-memory fake starts signed out; it exists for tests and previews.
    return null;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(latency);
  }

  void _ensurePasswordIsStrong(String password) {
    if (password.length < 6) {
      throw const AuthFailure('Password must be at least 6 characters.');
    }
  }

  static String _displayNameFromEmail(String email) {
    final String local = email.trim().split('@').first;
    if (local.isEmpty) return 'Friend';
    return _capitalize(local);
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

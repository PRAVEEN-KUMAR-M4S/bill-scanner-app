import 'package:bill_scanner/features/auth/domain/entities/auth_provider.dart';
import 'package:bill_scanner/features/auth/domain/entities/user.dart';
import 'package:bill_scanner/features/auth/domain/failures/auth_failure.dart';
import 'package:bill_scanner/features/auth/domain/repositories/auth_repository.dart';

/// In-memory stand-in for the account backend, used by widget tests.
///
/// Enforces the same rules the API enforces (a duplicate email is refused, a
/// short password is refused) so the presentation layer is tested against
/// realistic states without a network.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.latency = const Duration(milliseconds: 700)});

  /// Simulated round-trip time.
  final Duration latency;

  final Set<String> _registeredEmails = <String>{};

  @override
  Future<User> signIn({required String email, required String password}) async {
    await Future<void>.delayed(latency);
    _ensurePasswordIsStrong(password);
    return User(
      id: email.trim().toLowerCase(),
      name: _displayNameFromEmail(email),
      email: email.trim(),
    );
  }

  @override
  Future<User> register({
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
    return User(
      id: email.trim().toLowerCase(),
      name: name.trim(),
      email: email.trim(),
    );
  }

  @override
  Future<User> signInWithProvider(AuthProvider provider) async {
    await Future<void>.delayed(latency);
    return User(
      id: '${provider.name}-demo',
      name: '${_capitalize(provider.name)} User',
      email: 'you@${provider.name}.com',
    );
  }

  @override
  Future<User> continueAsGuest() async {
    await Future<void>.delayed(latency);
    return const User(id: 'guest', name: 'Guest', email: '', isGuest: true);
  }

  @override
  Future<User?> restoreSession() async {
    // The fake starts signed out; tests pass `restoredUser` when they need one.
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

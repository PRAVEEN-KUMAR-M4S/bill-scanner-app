import '../../domain/entities/auth_provider.dart';
import '../../domain/entities/user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_tokens.dart';
import '../models/user_model.dart';
import '../session/auth_session_store.dart';

/// Authentication backed by the Bill Reader API, with the session kept on the
/// device.
///
/// [AuthRemoteDataSource] has already turned HTTP problems into
/// [AuthFailure]s, so this class only decides what a failure means for the
/// stored session: a failed sign-in clears it, and a rejected refresh ends it.
///
/// The API has no profile or display-name field, so:
/// - the name typed on the register form is kept for the new session;
/// - on later sign-ins the name is derived from the email local part
///   (`asha.tiffins@…` becomes "Asha Tiffins").
///
/// Provider buttons have no endpoint yet and fail with a clear message rather
/// than pretending to sign in.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthSessionStore session,
  }) : _remote = remote,
       _session = session;

  final AuthRemoteDataSource _remote;
  final AuthSessionStore _session;

  @override
  Future<User> signIn({required String email, required String password}) async {
    final String cleanEmail = email.trim();
    try {
      await _session.save(
        await _remote.login(email: cleanEmail, password: password),
      );
      final UserModel profile = await _remote.me();
      final User user = User(
        id: profile.id,
        name: _displayName(profile.email),
        email: profile.email,
      );
      await _session.saveUser(user);
      return user;
    } on AuthFailure {
      // A half-finished sign-in must not leave tokens behind.
      await _session.clear();
      rethrow;
    }
  }

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim();
    try {
      await _remote.register(email: cleanEmail, password: password);
      await _session.save(
        await _remote.login(email: cleanEmail, password: password),
      );
      final UserModel profile = await _remote.me();
      final String display = name.trim();
      final User user = User(
        id: profile.id,
        name: display.isEmpty ? _displayName(profile.email) : display,
        email: profile.email,
      );
      await _session.saveUser(user);
      return user;
    } on AuthFailure {
      await _session.clear();
      rethrow;
    }
  }

  @override
  Future<User> signInWithProvider(AuthProvider provider) async {
    throw AuthFailure(
      '${_providerLabel(provider)} sign-in is not available yet. '
      'Use email or continue as a guest.',
    );
  }

  @override
  Future<User> continueAsGuest() async {
    const User guest = User(
      id: 'guest',
      name: 'Guest',
      email: '',
      isGuest: true,
    );
    await _session.saveUser(guest);
    return guest;
  }

  /// Returns the session saved on this device, without a network call when the
  /// profile was stored with the tokens.
  @override
  Future<User?> restoreSession() async {
    if (_session.user != null) return _session.user;
    if (!_session.hasSession) return null;

    try {
      final UserModel profile = await _remote.me();
      final User user = User(
        id: profile.id,
        name: _displayName(profile.email),
        email: profile.email,
      );
      await _session.saveUser(user);
      return user;
    } on AuthFailure {
      // Stored tokens the API no longer accepts: start signed out.
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final String? refreshToken = _session.refreshToken;
    await _session.clear();

    if (refreshToken == null) return;
    try {
      await _remote.logout(refreshToken);
    } on AuthFailure {
      // Revocation is best-effort: the local session is already gone, and a
      // network failure must not keep the user signed in.
    }
  }

  /// Rotates the session after a 401 on an authenticated request.
  ///
  /// The access token lives for 30 minutes; bill endpoints are the first calls
  /// that will use this.
  Future<bool> refreshSession() async {
    final String? refreshToken = _session.refreshToken;
    if (refreshToken == null) return false;

    try {
      final AuthTokens tokens = await _remote.refresh(refreshToken);
      await _session.save(tokens);
      return true;
    } on AuthFailure {
      await _session.clear();
      return false;
    }
  }

  String _providerLabel(AuthProvider provider) {
    return switch (provider) {
      AuthProvider.google => 'Google',
      AuthProvider.apple => 'Apple',
    };
  }

  String _displayName(String email) {
    final String local = email.split('@').first;
    final List<String> words = local
        .split(RegExp(r'[._\-]+'))
        .where((String word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return 'Friend';
    return words.map(_capitalize).join(' ');
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

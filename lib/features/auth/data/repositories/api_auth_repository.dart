import '../../../../core/network/api_exception.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_provider.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_api.dart';
import '../models/api_user.dart';
import '../models/auth_tokens.dart';
import '../session/auth_token_store.dart';

/// Authentication backed by the Bill Reader API.
///
/// The API has no profile or display-name field, so:
/// - the entered name is kept for the session created by registration;
/// - on later sign-ins the name is derived from the email local part
///   (`asha.tiffins@…` becomes "Asha Tiffins").
///
/// Provider buttons have no endpoint yet and fail with a clear message rather
/// than pretending to sign in.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({required AuthApi authApi, required AuthTokenStore tokens})
    : _authApi = authApi,
      _tokens = tokens;

  final AuthApi _authApi;
  final AuthTokenStore _tokens;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim();
    try {
      await _tokens.save(
        await _authApi.login(email: cleanEmail, password: password),
      );
      final ApiUser profile = await _authApi.me();
      final AppUser user = AppUser(
        id: profile.id,
        name: _displayName(profile.email),
        email: profile.email,
      );
      await _tokens.saveUser(user);
      return user;
    } on ApiException catch (exception) {
      await _tokens.clear();
      throw _failureFor(exception, signingIn: true);
    }
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final String cleanEmail = email.trim();
    try {
      await _authApi.register(email: cleanEmail, password: password);
      await _tokens.save(
        await _authApi.login(email: cleanEmail, password: password),
      );
      final ApiUser profile = await _authApi.me();
      final String display = name.trim();
      final AppUser user = AppUser(
        id: profile.id,
        name: display.isEmpty ? _displayName(profile.email) : display,
        email: profile.email,
      );
      await _tokens.saveUser(user);
      return user;
    } on ApiException catch (exception) {
      await _tokens.clear();
      throw _failureFor(exception, signingIn: false);
    }
  }

  @override
  Future<AppUser> signInWithProvider(AuthProvider provider) async {
    throw AuthFailure(
      '${_providerLabel(provider)} sign-in is not available yet. '
      'Use email or continue as a guest.',
    );
  }

  @override
  Future<AppUser> continueAsGuest() async {
    const AppUser guest = AppUser(
      id: 'guest',
      name: 'Guest',
      email: '',
      isGuest: true,
    );
    await _tokens.saveUser(guest);
    return guest;
  }

  /// Returns the session saved on this device, without a network call when the
  /// profile was stored with the tokens.
  @override
  Future<AppUser?> restoreSession() async {
    if (_tokens.user != null) return _tokens.user;
    if (!_tokens.hasSession) return null;

    try {
      final ApiUser profile = await _authApi.me();
      final AppUser user = AppUser(
        id: profile.id,
        name: _displayName(profile.email),
        email: profile.email,
      );
      await _tokens.saveUser(user);
      return user;
    } on ApiException {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    final String? refreshToken = _tokens.refreshToken;
    await _tokens.clear();

    if (refreshToken == null) return;
    try {
      await _authApi.logout(refreshToken);
    } on ApiException {
      // Revocation is best-effort: the local session is already gone, and a
      // network failure must not keep the user signed in.
    }
  }

  /// Rotates the session after a 401 on an authenticated request.
  ///
  /// The access token lives for 30 minutes; bill endpoints (Phase 6) are the
  /// first calls that will use this.
  Future<bool> refreshSession() async {
    final String? refreshToken = _tokens.refreshToken;
    if (refreshToken == null) return false;

    try {
      final AuthTokens tokens = await _authApi.refresh(refreshToken);
      await _tokens.save(tokens);
      return true;
    } on ApiException {
      await _tokens.clear();
      return false;
    }
  }

  AuthFailure _failureFor(ApiException exception, {required bool signingIn}) {
    final bool duplicateAccount =
        exception is ConflictApiException ||
        (exception is BadRequestApiException &&
            _mentionsExistingAccount(exception.body));

    if (exception is UnauthorizedApiException) {
      return AuthFailure(
        signingIn
            ? 'Email or password is incorrect.'
            : 'Your session expired. Please sign in again.',
      );
    }

    if (duplicateAccount) {
      return const AuthFailure(
        'That email is already registered. Try signing in.',
      );
    }

    if (exception is ValidationApiException) {
      return AuthFailure(
        exception.fields['password'] ??
            exception.fields['email'] ??
            exception.message,
      );
    }

    if (exception is NetworkApiException || exception is TimeoutApiException) {
      return const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (exception is RateLimitedApiException) {
      return const AuthFailure('Too many attempts. Try again in a minute.');
    }

    if (exception is ApiFormatException) {
      return const AuthFailure('The server sent an unexpected response.');
    }

    return const AuthFailure('Something went wrong. Please try again.');
  }

  bool _mentionsExistingAccount(String? body) {
    final String text = body?.toLowerCase() ?? '';
    return text.contains('already') ||
        text.contains('exists') ||
        text.contains('registered');
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

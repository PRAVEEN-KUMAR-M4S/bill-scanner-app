import '../../domain/entities/app_user.dart';
import '../models/auth_tokens.dart';
import 'session_storage.dart';

/// Holds the current session and writes it through [SessionStorage].
///
/// The access token is read synchronously by [ApiService] before an
/// authenticated request, so reads stay in memory; writes go to storage (in
/// production, SharedPreferences) so the next launch can restore the session
/// without a round trip.
class AuthTokenStore {
  AuthTokenStore({SessionStorage? storage})
    : _storage = storage ?? InMemorySessionStorage();

  static const String accessTokenKey = 'session.access_token';
  static const String refreshTokenKey = 'session.refresh_token';
  static const String userIdKey = 'session.user_id';
  static const String userNameKey = 'session.user_name';
  static const String userEmailKey = 'session.user_email';
  static const String userIsGuestKey = 'session.user_is_guest';

  final SessionStorage _storage;

  String? _accessToken;
  String? _refreshToken;
  AppUser? _user;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  AppUser? get user => _user;

  bool get hasSession => _accessToken != null && _accessToken!.isNotEmpty;

  /// True for a token session or a guest session restored from storage.
  bool get isSignedIn => hasSession || _user != null;

  /// Loads a previously saved session. Safe to call when nothing is stored.
  Future<void> restore() async {
    _accessToken = _storage.read(accessTokenKey);
    _refreshToken = _storage.read(refreshTokenKey);

    final String? id = _storage.read(userIdKey);
    final String? name = _storage.read(userNameKey);
    if (id == null || name == null) {
      _user = null;
      return;
    }

    _user = AppUser(
      id: id,
      name: name,
      email: _storage.read(userEmailKey) ?? '',
      isGuest: _storage.read(userIsGuestKey) == 'true',
    );
  }

  /// Stores a token pair and, when supplied, the account it belongs to.
  Future<void> save(AuthTokens tokens, {AppUser? user}) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    if (user != null) _user = user;

    await Future.wait(<Future<void>>[
      _storage.write(accessTokenKey, tokens.accessToken),
      _storage.write(refreshTokenKey, tokens.refreshToken),
      if (user != null) ..._userWrites(user),
    ]);
  }

  /// Remembers the profile separately from the tokens (guest mode has none).
  Future<void> saveUser(AppUser user) async {
    _user = user;
    await Future.wait(_userWrites(user));
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    await Future.wait(<Future<void>>[
      _storage.remove(accessTokenKey),
      _storage.remove(refreshTokenKey),
      _storage.remove(userIdKey),
      _storage.remove(userNameKey),
      _storage.remove(userEmailKey),
      _storage.remove(userIsGuestKey),
    ]);
  }

  List<Future<void>> _userWrites(AppUser user) {
    return <Future<void>>[
      _storage.write(userIdKey, user.id),
      _storage.write(userNameKey, user.name),
      _storage.write(userEmailKey, user.email),
      _storage.write(userIsGuestKey, user.isGuest.toString()),
    ];
  }
}

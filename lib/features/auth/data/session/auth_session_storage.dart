import 'package:shared_preferences/shared_preferences.dart';

/// Key/value storage used by [AuthSessionStore].
///
/// Split from the store so a unit test can keep a session in memory without a
/// plugin, and so swapping SharedPreferences for a secure vault later is one
/// class.
abstract interface class AuthSessionStorage {
  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// Keeps a session in a map for the lifetime of a test or a preview.
class InMemoryAuthSessionStorage implements AuthSessionStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  String? read(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }
}

/// Persists the signed-in session across app launches.
///
/// SharedPreferences is not a secure vault. It keeps the access token (30 min)
/// and the refresh token (30 days) so the user does not sign in on every start;
/// for a production build, swap this for `flutter_secure_storage` without
/// touching [AuthSessionStore] or any feature above it.
class SharedPreferencesAuthSessionStorage implements AuthSessionStorage {
  const SharedPreferencesAuthSessionStorage(this._preferences);

  final SharedPreferences _preferences;

  @override
  String? read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}

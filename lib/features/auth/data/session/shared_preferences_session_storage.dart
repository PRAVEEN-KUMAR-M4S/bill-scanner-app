import 'package:shared_preferences/shared_preferences.dart';

import 'session_storage.dart';

/// Persists the signed-in session across app launches.
///
/// SharedPreferences is not a secure vault. It keeps the access token (30 min)
/// and the refresh token (30 days) so the user does not sign in on every start;
/// for a production build, swap this for `flutter_secure_storage` without
/// touching [AuthTokenStore] or any feature above it.
class SharedPreferencesSessionStorage implements SessionStorage {
  const SharedPreferencesSessionStorage(this._preferences);

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

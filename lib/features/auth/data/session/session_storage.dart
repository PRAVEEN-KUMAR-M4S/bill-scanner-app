/// Key/value storage used by the session.
///
/// The production implementation is SharedPreferences; tests use the in-memory
/// one, so no plugin is required in a unit test.
abstract interface class SessionStorage {
  String? read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);
}

/// Keeps a session in a map for the lifetime of a test or a preview.
class InMemorySessionStorage implements SessionStorage {
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

/// Where the Bill Reader API lives.
///
/// Override the default at build time when the API is not on the development
/// machine:
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.example.com
/// ```
///
/// The default works for desktop, iOS simulator and web. The Android emulator
/// reaches the host through `10.0.2.2`, so pass
/// `--dart-define=API_BASE_URL=http://10.0.2.2:8000` there instead.
abstract final class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  /// Local development server started with `uv run main.py`.
  static const String defaultBaseUrl = 'http://192.168.1.41:8000';

  /// Base URI every request is resolved against.
  static Uri get baseUrl =>
      Uri.parse(_override.isEmpty ? defaultBaseUrl : _override);
}

/// Every URL path the app talks to, in one place.
///
/// Paths are relative to [ApiConfig.baseUrl]. Keeping them here means a route
/// rename is one edit, and no data source contains a hard-coded string.
///
/// The API is versioned by path (`/auth`, `/bills`); if a `/v1` prefix is added
/// later, [prefix] changes once and every path follows.
abstract final class ApiEndpoints {
  /// Common prefix for every endpoint. Empty while the API is unversioned.
  static const String prefix = '';

  // --- Authentication ------------------------------------------------------
  static const String authRegister = '$prefix/auth/register';
  static const String authLogin = '$prefix/auth/login';
  static const String authRefresh = '$prefix/auth/refresh';
  static const String authLogout = '$prefix/auth/logout';
  static const String authMe = '$prefix/auth/me';

  // --- Bills ---------------------------------------------------------------
  /// `GET` — every saved bill for the signed-in user.
  static const String bills = '$prefix/bills';

  /// `POST` multipart `file` — photo in, `{draft, problems}` out.
  static const String billsExtract = '$prefix/bills/extract';

  /// `POST` JSON `{draft}` — save only after the checks pass.
  static const String billsConfirm = '$prefix/bills/confirm';
}

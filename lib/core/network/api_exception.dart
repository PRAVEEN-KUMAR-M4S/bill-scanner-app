/// A failure raised by the network layer.
///
/// [message] is short and safe to show to a person; the data layer translates
/// individual kinds into feature-specific messages (for example "Email or
/// password is incorrect") when it knows more about the request.
sealed class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.body});

  final String message;

  /// HTTP status, or `null` when the request never got a response.
  final int? statusCode;

  /// Raw response body, kept for diagnostics and for narrow checks such as
  /// "does the server say this email already exists?".
  final String? body;

  @override
  String toString() => '$runtimeType(${statusCode ?? 'network'}): $message';
}

/// The device could not reach the server (no network, DNS, refused socket).
final class NetworkApiException extends ApiException {
  const NetworkApiException()
    : super('Could not reach the server. Check your connection.');
}

/// The server did not answer within [ApiService.timeout].
final class TimeoutApiException extends ApiException {
  const TimeoutApiException()
    : super('The server took too long to answer. Try again.');
}

/// 401 — the access token is missing, expired or not accepted.
final class UnauthorizedApiException extends ApiException {
  const UnauthorizedApiException([
    super.message = 'Your session has expired. Please sign in again.',
  ]) : super(statusCode: 401);
}

/// 403 — authenticated, but not allowed to perform this action.
final class ForbiddenApiException extends ApiException {
  const ForbiddenApiException([super.message = 'You cannot do that.'])
    : super(statusCode: 403);
}

/// 404 — the resource does not exist.
final class NotFoundApiException extends ApiException {
  const NotFoundApiException([super.message = 'That could not be found.'])
    : super(statusCode: 404);
}

/// 409 — the request collides with something that already exists.
final class ConflictApiException extends ApiException {
  const ConflictApiException([super.message = 'That already exists.'])
    : super(statusCode: 409);
}

/// 400 — the server rejected the request as malformed or not allowed.
final class BadRequestApiException extends ApiException {
  const BadRequestApiException(super.message, {super.body})
    : super(statusCode: 400);
}

/// One field-level problem returned by the API.
class ApiProblem {
  const ApiProblem({required this.field, required this.message});

  final String field;
  final String message;
}

/// 422 — field-level validation failed.
///
/// [fields] maps a field name such as `password` to the message that belongs
/// under that input; [message] is the first problem, suitable for a snack bar.
/// [problems] keeps every problem (and its order) when the server returns more
/// than one, as the bill checks do.
final class ValidationApiException extends ApiException {
  const ValidationApiException(
    this.fields,
    String message, {
    this.problems = const <ApiProblem>[],
    super.body,
  }) : super(message, statusCode: 422);

  final Map<String, String> fields;
  final List<ApiProblem> problems;
}

/// 413 — the uploaded file is over the server's size limit.
final class PayloadTooLargeApiException extends ApiException {
  const PayloadTooLargeApiException(
    super.message, {
    super.body,
    super.statusCode = 413,
  });
}

/// 415 — the uploaded file is not a type the server accepts.
final class UnsupportedMediaTypeApiException extends ApiException {
  const UnsupportedMediaTypeApiException(
    super.message, {
    super.body,
    super.statusCode = 415,
  });
}

/// 429 — too many requests. [retryAfter] comes from the response header when
/// the server sends one.
final class RateLimitedApiException extends ApiException {
  const RateLimitedApiException({this.retryAfter, String? body})
    : super(
        'Too many attempts. Try again shortly.',
        statusCode: 429,
        body: body,
      );

  final Duration? retryAfter;
}

/// 5xx — the server failed while handling a valid request.
final class ServerApiException extends ApiException {
  const ServerApiException({int? statusCode, String? body})
    : super(
        'The server had a problem. Try again.',
        statusCode: statusCode,
        body: body,
      );
}

/// Any other status, or a response the client did not understand.
final class UnknownApiException extends ApiException {
  const UnknownApiException({int? statusCode, String? body})
    : super(
        'Something went wrong. Try again.',
        statusCode: statusCode,
        body: body,
      );
}

/// A 2xx response whose body was not JSON in the shape the client expects.
final class ApiFormatException extends ApiException {
  const ApiFormatException({String? body})
    : super('The server sent an unexpected response.', body: body);
}

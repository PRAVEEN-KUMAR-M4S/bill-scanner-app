import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_exception.dart';

/// Reads the current access token, or `null` when nobody is signed in.
typedef AccessTokenReader = Future<String?> Function();

/// One binary file sent as `multipart/form-data`.
class ApiUploadFile {
  const ApiUploadFile({
    required this.field,
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  /// Form field name the server reads, for example `file`.
  final String field;
  final List<int> bytes;
  final String filename;

  /// MIME type such as `image/jpeg`; the server trusts this to accept a photo.
  final String contentType;
}

/// The one HTTP client every remote data source goes through.
///
/// Responsibilities kept in one place:
/// - building the absolute URI (base URL + path + query);
/// - JSON encoding/decoding;
/// - `Accept`, `Content-Type` and bearer-token headers;
/// - the request timeout;
/// - turning non-2xx responses into typed [ApiException]s.
///
/// It deliberately knows nothing about bills, users or widgets. Data sources
/// call [get], [post], [put] or [delete] and translate the exceptions into the
/// language of their own feature.
class ApiService {
  ApiService({
    required this.baseUrl,
    http.Client? client,
    AccessTokenReader? accessToken,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client(),
       _accessToken = accessToken;

  /// Root of the API, for example `http://127.0.0.1:8000`.
  final Uri baseUrl;

  /// How long a request may take before [TimeoutApiException] is thrown.
  final Duration timeout;

  final http.Client _client;
  final AccessTokenReader? _accessToken;

  /// GET [path] and decode the JSON response.
  Future<Object?> get(
    String path, {
    Map<String, String>? query,
    Map<String, String>? headers,
    bool authenticated = false,
  }) {
    return _send(
      'GET',
      path,
      query: query,
      headers: headers,
      authenticated: authenticated,
    );
  }

  /// POST [body] as JSON and decode the JSON response.
  Future<Object?> post(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool authenticated = false,
  }) {
    return _send(
      'POST',
      path,
      body: body,
      query: query,
      headers: headers,
      authenticated: authenticated,
    );
  }

  /// PUT [body] as JSON and decode the JSON response.
  Future<Object?> put(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool authenticated = false,
  }) {
    return _send(
      'PUT',
      path,
      body: body,
      query: query,
      headers: headers,
      authenticated: authenticated,
    );
  }

  /// POST a `multipart/form-data` body and decode the JSON response.
  ///
  /// Used for photo uploads, where the body is a file plus optional text
  /// fields. The same timeout and error mapping as the JSON verbs apply.
  Future<Object?> postMultipart(
    String path, {
    required ApiUploadFile file,
    Map<String, String>? fields,
    Map<String, String>? headers,
    bool authenticated = false,
  }) async {
    final Uri uri = _resolve(path, null);
    final Map<String, String> requestHeaders = await _headers(
      headers: headers,
      authenticated: authenticated,
      hasBody: false,
    );

    final http.Response response;
    try {
      final http.MultipartRequest request = http.MultipartRequest('POST', uri)
        ..headers.addAll(requestHeaders)
        ..files.add(
          http.MultipartFile.fromBytes(
            file.field,
            file.bytes,
            filename: file.filename,
            contentType: MediaType.parse(file.contentType),
          ),
        );
      if (fields != null) request.fields.addAll(fields);

      final http.StreamedResponse streamed = await _client
          .send(request)
          .timeout(timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const TimeoutApiException();
    } on http.ClientException {
      throw const NetworkApiException();
    }

    return _decode(response);
  }

  /// DELETE [path] and decode the JSON response when the server sends one.
  Future<Object?> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    bool authenticated = false,
  }) {
    return _send(
      'DELETE',
      path,
      body: body,
      query: query,
      headers: headers,
      authenticated: authenticated,
    );
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String>? headers,
    required bool authenticated,
  }) async {
    final Uri uri = _resolve(path, query);
    final Map<String, String> requestHeaders = await _headers(
      headers: headers,
      authenticated: authenticated,
      hasBody: body != null,
    );

    final http.Response response;
    try {
      final String? encodedBody = body == null ? null : jsonEncode(body);
      final Future<http.Response> pending = switch (method) {
        'GET' => _client.get(uri, headers: requestHeaders),
        'POST' => _client.post(uri, headers: requestHeaders, body: encodedBody),
        'PUT' => _client.put(uri, headers: requestHeaders, body: encodedBody),
        'DELETE' => _client.delete(
          uri,
          headers: requestHeaders,
          body: encodedBody,
        ),
        _ => throw ArgumentError.value(method, 'method'),
      };
      response = await pending.timeout(timeout);
    } on TimeoutException {
      throw const TimeoutApiException();
    } on http.ClientException {
      throw const NetworkApiException();
    }

    return _decode(response);
  }

  Uri _resolve(String path, Map<String, String>? query) {
    final String base = baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    final String suffix = path.startsWith('/') ? path : '/$path';
    final Uri uri = Uri.parse('$base$suffix');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    required bool hasBody,
    Map<String, String>? headers,
  }) async {
    final Map<String, String> result = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    if (hasBody && !result.containsKey('Content-Type')) {
      result['Content-Type'] = 'application/json';
    }

    if (authenticated) {
      final String? token = await _accessToken?.call();
      if (token == null || token.isEmpty) {
        throw const UnauthorizedApiException(
          'You need to sign in to continue.',
        );
      }
      result['Authorization'] = 'Bearer $token';
    }

    return result;
  }

  Object? _decode(http.Response response) {
    final String body = utf8.decode(response.bodyBytes, allowMalformed: true);
    final int status = response.statusCode;

    if (status >= 200 && status < 300) {
      if (body.trim().isEmpty) return null;
      try {
        return jsonDecode(body);
      } on FormatException {
        throw ApiFormatException(body: body);
      }
    }

    throw _error(status, body, response.headers['retry-after']);
  }

  ApiException _error(int status, String body, String? retryAfterHeader) {
    final _ErrorDetail detail = _readDetail(body);

    switch (status) {
      case 400:
        return BadRequestApiException(
          detail.message ?? 'That request was not accepted.',
          body: body,
        );
      case 401:
        return UnauthorizedApiException(
          detail.message ?? 'Your session has expired. Please sign in again.',
        );
      case 403:
        return ForbiddenApiException(detail.message ?? 'You cannot do that.');
      case 404:
        return NotFoundApiException(
          detail.message ?? 'That could not be found.',
        );
      case 409:
        return ConflictApiException(detail.message ?? 'That already exists.');
      case 413:
        return PayloadTooLargeApiException(
          detail.message ?? 'That file is too large.',
          body: body,
        );
      case 415:
        return UnsupportedMediaTypeApiException(
          detail.message ?? 'That file type is not supported.',
          body: body,
        );
      case 422:
        // The body is deliberately not kept for 422: FastAPI echoes the
        // rejected input (a password, for example) in `detail[].input`.
        return ValidationApiException(
          detail.fields,
          detail.message ?? 'Some fields need checking.',
          problems: detail.problems,
        );
      case 429:
        return RateLimitedApiException(
          retryAfter: _retryAfter(retryAfterHeader),
          body: body,
        );
    }

    if (status >= 500) {
      return ServerApiException(statusCode: status, body: body);
    }
    return UnknownApiException(statusCode: status, body: body);
  }

  _ErrorDetail _readDetail(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const _ErrorDetail();
    }

    if (decoded is! Map) return const _ErrorDetail();

    final Object? detail = decoded['detail'];
    if (detail is String) {
      return _ErrorDetail(message: detail);
    }

    // The bill endpoints wrap their refusal as
    // `{"detail": {"message": ..., "problems": [{field, message}]}}`.
    if (detail is Map) {
      final Object? message = detail['message'];
      final Object? rawProblems = detail['problems'];
      final List<ApiProblem> problems = <ApiProblem>[];
      final Map<String, String> fields = <String, String>{};

      if (rawProblems is List) {
        for (final Object? entry in rawProblems) {
          if (entry is! Map) continue;
          final Object? field = entry['field'];
          final Object? text = entry['message'];
          if (field is! String || text is! String || text.isEmpty) continue;
          problems.add(ApiProblem(field: field, message: text));
          fields[field] = text;
        }
      }

      return _ErrorDetail(
        message: message is String && message.isNotEmpty ? message : null,
        fields: fields,
        problems: problems,
      );
    }

    if (detail is List) {
      String? first;
      final Map<String, String> fields = <String, String>{};

      for (final Object? entry in detail) {
        if (entry is! Map) continue;
        final Object? message = entry['msg'];
        if (message is! String || message.isEmpty) continue;

        first ??= message;
        final Object? location = entry['loc'];
        if (location is List && location.isNotEmpty) {
          final Object? field = location.last;
          if (field is String) fields[field] = message;
        }
      }

      return _ErrorDetail(message: first, fields: fields);
    }

    return const _ErrorDetail();
  }

  Duration? _retryAfter(String? header) {
    if (header == null) return null;
    final int? seconds = int.tryParse(header.trim());
    if (seconds == null || seconds <= 0) return null;
    return Duration(seconds: seconds);
  }
}

final class _ErrorDetail {
  const _ErrorDetail({
    this.message,
    this.fields = const <String, String>{},
    this.problems = const <ApiProblem>[],
  });

  final String? message;
  final Map<String, String> fields;
  final List<ApiProblem> problems;
}

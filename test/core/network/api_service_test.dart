import 'dart:convert';

import 'package:bill_scanner/core/network/api_exception.dart';
import 'package:bill_scanner/core/network/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiService serviceWith(
  MockClient client, {
  AccessTokenReader? token,
  Duration timeout = const Duration(seconds: 5),
}) {
  return ApiService(
    baseUrl: Uri.parse('http://api.test:8000'),
    client: client,
    accessToken: token,
    timeout: timeout,
  );
}

void main() {
  group('ApiService', () {
    test('GET builds the query, attaches the token and decodes JSON', () async {
      late http.Request seen;
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          seen = request;
          return http.Response(
            jsonEncode(<String, dynamic>{'email': 'asha@billo.app'}),
            200,
          );
        }),
        token: () async => 'access-1',
      );

      final Object? body = await service.get(
        '/auth/me',
        query: <String, String>{'verbose': '1'},
        authenticated: true,
      );

      expect(body, <String, dynamic>{'email': 'asha@billo.app'});
      expect(seen.method, 'GET');
      expect(seen.url.toString(), 'http://api.test:8000/auth/me?verbose=1');
      expect(seen.headers['authorization'], 'Bearer access-1');
    });

    test('POST sends a JSON body and a JSON content type', () async {
      late http.Request seen;
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          seen = request;
          return http.Response('{"ok":true}', 200);
        }),
      );

      final Object? body = await service.post(
        '/auth/login',
        body: <String, String>{
          'email': 'asha@billo.app',
          'password': 'secret123',
        },
      );

      expect(body, <String, dynamic>{'ok': true});
      expect(seen.method, 'POST');
      expect(seen.headers['content-type'], contains('application/json'));
      expect(jsonDecode(seen.body), <String, dynamic>{
        'email': 'asha@billo.app',
        'password': 'secret123',
      });
    });

    test('PUT sends the body and decodes the response', () async {
      late http.Request seen;
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          seen = request;
          return http.Response('{"updated":true}', 200);
        }),
      );

      final Object? body = await service.put(
        '/bills/1',
        body: <String, String>{'shop': 'Lulu'},
      );

      expect(body, <String, dynamic>{'updated': true});
      expect(seen.method, 'PUT');
      expect(jsonDecode(seen.body), <String, String>{'shop': 'Lulu'});
    });

    test('DELETE accepts an empty 204 response', () async {
      late http.Request seen;
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          seen = request;
          return http.Response('', 204);
        }),
      );

      final Object? body = await service.delete('/bills/1');

      expect(body, isNull);
      expect(seen.method, 'DELETE');
    });

    test(
      'authenticated requests without a token never reach the network',
      () async {
        bool called = false;
        final ApiService service = serviceWith(
          MockClient((http.Request request) async {
            called = true;
            return http.Response('{}', 200);
          }),
          token: () async => null,
        );

        await expectLater(
          service.get('/auth/me', authenticated: true),
          throwsA(isA<UnauthorizedApiException>()),
        );
        expect(called, isFalse);
      },
    );

    test('maps 401, 409, 500 and 429 to their exception types', () async {
      Future<ApiException> errorFor(http.Response response) async {
        final ApiService service = serviceWith(
          MockClient((http.Request request) async => response),
        );
        try {
          await service.get('/anything');
          fail('Expected an ApiException');
        } on ApiException catch (exception) {
          return exception;
        }
      }

      expect(
        await errorFor(http.Response('{"detail":"nope"}', 401)),
        isA<UnauthorizedApiException>(),
      );
      expect(
        await errorFor(http.Response('{"detail":"duplicate"}', 409)),
        isA<ConflictApiException>(),
      );
      expect(
        await errorFor(http.Response('{"detail":"boom"}', 500)),
        isA<ServerApiException>(),
      );

      final ApiException limited = await errorFor(
        http.Response(
          '{"detail":"slow down"}',
          429,
          headers: <String, String>{'retry-after': '60'},
        ),
      );
      expect(limited, isA<RateLimitedApiException>());
      expect(
        (limited as RateLimitedApiException).retryAfter,
        const Duration(seconds: 60),
      );
    });

    test('reads FastAPI field errors from a 422', () async {
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'detail': <Map<String, dynamic>>[
                <String, dynamic>{
                  'type': 'string_too_short',
                  'loc': <String>['body', 'password'],
                  'msg': 'String should have at least 6 characters',
                },
              ],
            }),
            422,
          );
        }),
      );

      await expectLater(
        service.post('/auth/login', body: <String, String>{}),
        throwsA(
          isA<ValidationApiException>()
              .having(
                (ValidationApiException e) => e.fields['password'],
                'password message',
                'String should have at least 6 characters',
              )
              .having(
                (ValidationApiException e) => e.message,
                'headline message',
                'String should have at least 6 characters',
              ),
        ),
      );
    });

    test('maps a slow request to TimeoutApiException', () async {
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return http.Response('{}', 200);
        }),
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        service.get('/slow'),
        throwsA(isA<TimeoutApiException>()),
      );
    });

    test('maps a client failure to NetworkApiException', () async {
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        service.get('/auth/me'),
        throwsA(isA<NetworkApiException>()),
      );
    });

    test('POST multipart sends the file and bearer token', () async {
      late http.Request seen;
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          seen = request;
          return http.Response('{"ok":true}', 200);
        }),
        token: () async => 'access-1',
      );

      final Object? body = await service.postMultipart(
        '/bills/extract',
        file: const ApiUploadFile(
          field: 'file',
          bytes: <int>[1, 2, 3],
          filename: 'bill.jpg',
          contentType: 'image/jpeg',
        ),
        authenticated: true,
      );

      final String raw = latin1.decode(seen.bodyBytes);
      expect(body, <String, dynamic>{'ok': true});
      expect(seen.method, 'POST');
      expect(seen.url.path, '/bills/extract');
      expect(seen.headers['authorization'], 'Bearer access-1');
      expect(seen.headers['content-type'], startsWith('multipart/form-data'));
      expect(raw, contains('name="file"'));
      expect(raw, contains('filename="bill.jpg"'));
      expect(raw.toLowerCase(), contains('content-type: image/jpeg'));
    });

    test('maps 413, 415 and the bill 422 problem list', () async {
      Future<ApiException> errorFor(http.Response response) async {
        final ApiService service = serviceWith(
          MockClient((http.Request request) async => response),
        );
        try {
          await service.get('/bills');
          fail('Expected an ApiException');
        } on ApiException catch (exception) {
          return exception;
        }
      }

      expect(
        await errorFor(http.Response('{"detail":"too big"}', 413)),
        isA<PayloadTooLargeApiException>(),
      );
      expect(
        await errorFor(http.Response('{"detail":"wrong type"}', 415)),
        isA<UnsupportedMediaTypeApiException>(),
      );

      final ApiException refused = await errorFor(
        http.Response(
          jsonEncode(<String, dynamic>{
            'detail': <String, dynamic>{
              'message': 'Fix the highlighted fields before saving.',
              'problems': <Map<String, dynamic>>[
                <String, dynamic>{
                  'field': 'total',
                  'message': 'Items add up to 125.00 but the total says 99.99.',
                },
              ],
            },
          }),
          422,
        ),
      );
      expect(refused, isA<ValidationApiException>());
      final ValidationApiException validation =
          refused as ValidationApiException;
      expect(validation.message, 'Fix the highlighted fields before saving.');
      expect(validation.problems, hasLength(1));
      expect(validation.problems.single.field, 'total');
      expect(validation.fields['total'], contains('99.99'));
    });

    test('rejects a success body that is not JSON', () async {
      final ApiService service = serviceWith(
        MockClient((http.Request request) async {
          return http.Response('<html>proxy</html>', 200);
        }),
      );

      await expectLater(
        service.get('/auth/me'),
        throwsA(isA<ApiFormatException>()),
      );
    });
  });
}

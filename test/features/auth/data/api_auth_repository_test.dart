import 'dart:convert';

import 'package:bill_scanner/core/network/api_service.dart';
import 'package:bill_scanner/features/auth/data/datasources/auth_api.dart';
import 'package:bill_scanner/features/auth/data/models/auth_tokens.dart';
import 'package:bill_scanner/features/auth/data/repositories/api_auth_repository.dart';
import 'package:bill_scanner/features/auth/data/session/auth_token_store.dart';
import 'package:bill_scanner/features/auth/domain/entities/app_user.dart';
import 'package:bill_scanner/features/auth/domain/entities/auth_provider.dart';
import 'package:bill_scanner/features/auth/domain/failures/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late AuthTokenStore tokens;

  ApiAuthRepository repositoryWith(MockClient client) {
    tokens = AuthTokenStore();
    return ApiAuthRepository(
      authApi: AuthApi(
        ApiService(
          baseUrl: Uri.parse('http://api.test'),
          client: client,
          accessToken: () async => tokens.accessToken,
        ),
      ),
      tokens: tokens,
    );
  }

  http.Response jsonResponse(Object body, [int status = 200]) {
    return http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }

  group('ApiAuthRepository', () {
    test('sign in stores the tokens and loads the profile', () async {
      final List<String> calls = <String>[];
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          calls.add('${request.method} ${request.url.path}');
          switch (request.url.path) {
            case '/auth/login':
              expect(jsonDecode(request.body), <String, dynamic>{
                'email': 'asha.tiffins@billo.app',
                'password': 'secret123',
              });
              return jsonResponse(<String, dynamic>{
                'access_token': 'access-1',
                'refresh_token': 'refresh-1',
              });
            case '/auth/me':
              expect(request.headers['authorization'], 'Bearer access-1');
              return jsonResponse(<String, dynamic>{
                'id': 7,
                'email': 'asha.tiffins@billo.app',
              });
            default:
              return jsonResponse(<String, dynamic>{}, 404);
          }
        }),
      );

      final AppUser user = await repository.signIn(
        email: '  asha.tiffins@billo.app ',
        password: 'secret123',
      );

      expect(user.id, '7');
      expect(user.email, 'asha.tiffins@billo.app');
      expect(user.name, 'Asha Tiffins');
      expect(tokens.accessToken, 'access-1');
      expect(tokens.refreshToken, 'refresh-1');
      expect(calls, <String>['POST /auth/login', 'GET /auth/me']);
    });

    test('register keeps the typed name for the new session', () async {
      final List<String> calls = <String>[];
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          calls.add('${request.method} ${request.url.path}');
          switch (request.url.path) {
            case '/auth/register':
              expect(jsonDecode(request.body), <String, dynamic>{
                'email': 'asha@billo.app',
                'password': 'secret123',
              });
              return jsonResponse(<String, dynamic>{
                'id': 7,
                'email': 'asha@billo.app',
              }, 201);
            case '/auth/login':
              return jsonResponse(<String, dynamic>{
                'access_token': 'access-1',
                'refresh_token': 'refresh-1',
              });
            case '/auth/me':
              return jsonResponse(<String, dynamic>{
                'id': 7,
                'email': 'asha@billo.app',
              });
            default:
              return jsonResponse(<String, dynamic>{}, 404);
          }
        }),
      );

      final AppUser user = await repository.register(
        name: 'Asha Tiffins',
        email: 'asha@billo.app',
        password: 'secret123',
      );

      expect(user.name, 'Asha Tiffins');
      expect(tokens.hasSession, isTrue);
      expect(calls, <String>[
        'POST /auth/register',
        'POST /auth/login',
        'GET /auth/me',
      ]);
    });

    test('a duplicate registration becomes a friendly failure', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          if (request.url.path == '/auth/register') {
            return jsonResponse(<String, dynamic>{
              'detail': 'Email already registered',
            }, 400);
          }
          return jsonResponse(<String, dynamic>{}, 404);
        }),
      );

      await expectLater(
        repository.register(
          name: 'Asha',
          email: 'asha@billo.app',
          password: 'secret123',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure failure) => failure.message,
            'message',
            'That email is already registered. Try signing in.',
          ),
        ),
      );
      expect(tokens.hasSession, isFalse);
    });

    test('a rejected password reports invalid credentials', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          return jsonResponse(<String, dynamic>{
            'detail': 'Incorrect email or password',
          }, 401);
        }),
      );

      await expectLater(
        repository.signIn(email: 'asha@billo.app', password: 'wrong'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure failure) => failure.message,
            'message',
            'Email or password is incorrect.',
          ),
        ),
      );
      expect(tokens.hasSession, isFalse);
    });

    test('field validation from the server reaches the form', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          return jsonResponse(<String, dynamic>{
            'detail': <Map<String, dynamic>>[
              <String, dynamic>{
                'type': 'string_too_short',
                'loc': <String>['body', 'password'],
                'msg': 'String should have at least 6 characters',
              },
            ],
          }, 422);
        }),
      );

      await expectLater(
        repository.register(
          name: 'Asha',
          email: 'asha@billo.app',
          password: '123',
        ),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure failure) => failure.message,
            'message',
            'String should have at least 6 characters',
          ),
        ),
      );
    });

    test('an unreachable server explains the connection problem', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        repository.signIn(email: 'asha@billo.app', password: 'secret123'),
        throwsA(
          isA<AuthFailure>().having(
            (AuthFailure failure) => failure.message,
            'message',
            'Could not reach the server. Check your connection and try again.',
          ),
        ),
      );
    });

    test('sign out revokes the session and clears the tokens', () async {
      late http.Request logout;
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          logout = request;
          return http.Response('', 204);
        }),
      );
      tokens.save(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      await repository.signOut();

      expect(jsonDecode(logout.body), <String, dynamic>{
        'refresh_token': 'refresh-1',
      });
      expect(tokens.accessToken, isNull);
      expect(tokens.refreshToken, isNull);
    });

    test('sign out still clears the tokens when the server is down', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          throw http.ClientException('offline');
        }),
      );
      tokens.save(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      await repository.signOut();

      expect(tokens.hasSession, isFalse);
    });

    test('refresh rotates the stored pair', () async {
      late http.Request refresh;
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          refresh = request;
          return jsonResponse(<String, dynamic>{
            'access_token': 'access-2',
            'refresh_token': 'refresh-2',
          });
        }),
      );
      tokens.save(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      final bool rotated = await repository.refreshSession();

      expect(rotated, isTrue);
      expect(jsonDecode(refresh.body), <String, dynamic>{
        'refresh_token': 'refresh-1',
      });
      expect(tokens.accessToken, 'access-2');
      expect(tokens.refreshToken, 'refresh-2');
    });

    test('a rejected refresh ends the session', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          return jsonResponse(<String, dynamic>{'detail': 'expired'}, 401);
        }),
      );
      tokens.save(
        const AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );

      expect(await repository.refreshSession(), isFalse);
      expect(tokens.hasSession, isFalse);
    });

    test(
      'provider sign-in reports that the backend does not offer it',
      () async {
        final ApiAuthRepository repository = repositoryWith(
          MockClient((http.Request request) async {
            fail('Provider sign-in must not make a request');
          }),
        );

        await expectLater(
          repository.signInWithProvider(AuthProvider.google),
          throwsA(
            isA<AuthFailure>().having(
              (AuthFailure failure) => failure.message,
              'message',
              contains('Google sign-in is not available yet'),
            ),
          ),
        );
      },
    );

    test('guest mode stays local', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          fail('Guest mode must not make a request');
        }),
      );

      final AppUser guest = await repository.continueAsGuest();

      expect(guest.isGuest, isTrue);
      expect(guest.email, isEmpty);
      expect(tokens.hasSession, isFalse);
    });

    test('a malformed success body is reported as a server problem', () async {
      final ApiAuthRepository repository = repositoryWith(
        MockClient((http.Request request) async {
          return http.Response('not json', 200);
        }),
      );

      await expectLater(
        repository.signIn(email: 'asha@billo.app', password: 'secret123'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });
}

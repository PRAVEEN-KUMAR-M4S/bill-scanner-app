import 'dart:convert';

import 'package:bill_scanner/core/network/api_service.dart';
import 'package:bill_scanner/features/bills/data/datasources/bill_remote_datasource.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_category.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_extraction.dart';
import 'package:bill_scanner/features/bills/domain/entities/bill_item.dart';
import 'package:bill_scanner/features/bills/domain/failures/bill_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiService serviceWith(MockClient client) {
  return ApiService(
    baseUrl: Uri.parse('http://api.test'),
    client: client,
    accessToken: () async => 'access-1',
  );
}

Map<String, dynamic> expenseJson() {
  return <String, dynamic>{
    'id': 7,
    'shop': 'Lulu Supermarket',
    'date': '2026-10-22',
    'currency': 'INR',
    'total': '125.00',
    'category': 'groceries',
    'icon': 'strokeRoundedShoppingBasket01',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{'name': 'Rice 1kg', 'qty': 2, 'amount': '80.00'},
      <String, dynamic>{'name': 'Milk', 'qty': null, 'amount': '45.00'},
    ],
    'notes': null,
  };
}

void main() {
  group('endpoints', () {
    test('GET /bills maps rows, line amounts and the null quantity', () async {
      late http.Request seen;
      final BillRemoteDataSource remote = BillRemoteDataSource(
        serviceWith(
          MockClient((http.Request request) async {
            seen = request;
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[expenseJson()]),
              200,
            );
          }),
        ),
      );

      final List<Bill> bills = await remote.fetchAll();

      expect(seen.method, 'GET');
      expect(seen.url.path, '/bills');
      expect(seen.headers['authorization'], 'Bearer access-1');

      expect(bills, hasLength(1));
      final Bill bill = bills.single;
      expect(bill.id, '7');
      expect(bill.merchant, 'Lulu Supermarket');
      expect(bill.date, DateTime(2026, 10, 22));
      expect(bill.total, 125);
      expect(bill.currency, 'INR');
      expect(bill.category, BillCategory.groceries);
      expect(bill.icon, 'strokeRoundedShoppingBasket01');
      expect(bill.items[0].amount, 80);
      expect(bill.items[0].quantity, 2);
      expect(bill.items[1].quantity, isNull);
      expect(bill.itemsTotal, 125);
    });

    test(
      'POST /bills/extract sends a JPG/PNG part and reads problems',
      () async {
        late http.Request seen;
        final BillRemoteDataSource remote = BillRemoteDataSource(
          serviceWith(
            MockClient((http.Request request) async {
              seen = request;
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'draft': <String, dynamic>{
                    'shop': 'VCARE Medicals',
                    'date': '2026-10-21',
                    'currency': 'INR',
                    'category': 'health',
                    'icon': 'strokeRoundedMedicine01',
                    'total': '128.00',
                    'round_off': null,
                    'items': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'name': 'NONURD LC TAB',
                        'qty': 10,
                        'amount': '127.49',
                      },
                    ],
                    'notes': null,
                  },
                  'problems': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'field': 'total',
                      'message':
                          'Items add up to 127.49 but the total says 128.00.',
                    },
                  ],
                }),
                200,
              );
            }),
          ),
        );

        final BillExtraction report = await remote.extract(
          bytes: <int>[1, 2, 3, 4],
          filename: 'bill.png',
          contentType: 'image/png',
        );

        final String body = utf8.decode(seen.bodyBytes, allowMalformed: true);
        expect(seen.method, 'POST');
        expect(seen.url.path, '/bills/extract');
        expect(seen.headers['authorization'], 'Bearer access-1');
        expect(seen.headers['content-type'], startsWith('multipart/form-data'));
        expect(body, contains('name="file"'));
        expect(body, contains('filename="bill.png"'));
        expect(body.toLowerCase(), contains('content-type: image/png'));

        expect(report.bill.merchant, 'VCARE Medicals');
        expect(report.bill.category, BillCategory.health);
        expect(report.bill.items.single.amount, 127.49);
        expect(report.bill.items.single.quantity, 10);
        expect(report.problems, hasLength(1));
        expect(report.problems.single.field, 'total');
        expect(report.isClean, isFalse);
      },
    );

    test(
      'POST /bills/confirm sends the edited draft and returns the row',
      () async {
        late http.Request seen;
        final BillRemoteDataSource remote = BillRemoteDataSource(
          serviceWith(
            MockClient((http.Request request) async {
              seen = request;
              return http.Response(jsonEncode(expenseJson()), 201);
            }),
          ),
        );

        final Bill bill = Bill(
          id: '',
          merchant: 'Lulu Supermarket',
          date: DateTime(2026, 10, 22),
          total: 125,
          category: BillCategory.groceries,
          items: const <BillItem>[
            BillItem(name: 'Rice 1kg', quantity: 2, amount: 80),
            BillItem(name: 'Milk', amount: 45),
          ],
        );

        final Bill saved = await remote.confirm(bill);

        final Map<String, dynamic> body =
            jsonDecode(seen.body) as Map<String, dynamic>;
        final Map<String, dynamic> draft =
            body['draft'] as Map<String, dynamic>;
        expect(seen.method, 'POST');
        expect(seen.url.path, '/bills/confirm');
        expect(seen.headers['authorization'], 'Bearer access-1');
        expect(draft['shop'], 'Lulu Supermarket');
        expect(draft['date'], '2026-10-22');
        expect(draft['currency'], 'INR');
        expect(draft['category'], 'groceries');
        expect(draft['icon'], 'strokeRoundedShoppingBasket01');
        expect(draft['total'], '125.00');
        expect(draft['round_off'], isNull);
        expect(draft['items'], <Map<String, dynamic>>[
          <String, dynamic>{'name': 'Rice 1kg', 'qty': 2, 'amount': '80.00'},
          <String, dynamic>{'name': 'Milk', 'qty': null, 'amount': '45.00'},
        ]);

        expect(saved.id, '7');
        expect(saved.total, 125);
        expect(saved.isSaved, isTrue);
      },
    );
  });

  group('failures', () {
    test('a refused confirm keeps the server problems', () async {
      final BillRemoteDataSource remote = BillRemoteDataSource(
        serviceWith(
          MockClient((http.Request request) async {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'detail': <String, dynamic>{
                  'message': 'Fix the highlighted fields before saving.',
                  'problems': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'field': 'total',
                      'message':
                          'Items add up to 125.00 but the total says 99.99.',
                    },
                    <String, dynamic>{
                      'field': 'items[0].amount',
                      'message': 'Line amount is unreadable.',
                    },
                  ],
                },
              }),
              422,
            );
          }),
        ),
      );

      await expectLater(
        remote.confirm(
          Bill(
            id: '',
            merchant: 'Lulu',
            date: DateTime(2026, 10, 22),
            total: 99.99,
            category: BillCategory.groceries,
            items: const <BillItem>[BillItem(name: 'Rice', amount: 125)],
          ),
        ),
        throwsA(
          isA<BillFailure>()
              .having(
                (BillFailure failure) => failure.message,
                'message',
                'Fix the highlighted fields before saving.',
              )
              .having(
                (BillFailure failure) => failure.problems,
                'problems',
                hasLength(2),
              )
              .having(
                (BillFailure failure) => failure.isOffline,
                'isOffline',
                isFalse,
              ),
        ),
      );
    });

    test('a photo over the limit becomes a readable failure', () async {
      final BillRemoteDataSource remote = BillRemoteDataSource(
        serviceWith(
          MockClient((http.Request request) async {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'detail': 'Photo is too large (max 5 MB).',
              }),
              413,
            );
          }),
        ),
      );

      await expectLater(
        remote.extract(
          bytes: <int>[0],
          filename: 'bill.jpg',
          contentType: 'image/jpeg',
        ),
        throwsA(
          isA<BillFailure>().having(
            (BillFailure failure) => failure.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    });

    test('an unreachable server is flagged as offline', () async {
      final BillRemoteDataSource remote = BillRemoteDataSource(
        serviceWith(
          MockClient((http.Request request) async {
            throw http.ClientException('offline');
          }),
        ),
      );

      await expectLater(
        remote.fetchAll(),
        throwsA(
          isA<BillFailure>()
              .having(
                (BillFailure failure) => failure.message,
                'message',
                contains('Could not reach the server'),
              )
              .having(
                (BillFailure failure) => failure.isOffline,
                'isOffline',
                isTrue,
              ),
        ),
      );
    });

    test('an expired session stops the read', () async {
      final BillRemoteDataSource remote = BillRemoteDataSource(
        serviceWith(
          MockClient((http.Request request) async {
            return http.Response('{"detail":"expired"}', 401);
          }),
        ),
      );

      await expectLater(
        remote.fetchAll(),
        throwsA(
          isA<BillFailure>().having(
            (BillFailure failure) => failure.message,
            'message',
            contains('session expired'),
          ),
        ),
      );
    });
  });
}

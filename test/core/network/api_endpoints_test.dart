import 'package:bill_scanner/core/network/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every endpoint is an absolute, unique path', () {
    const List<String> endpoints = <String>[
      ApiEndpoints.authRegister,
      ApiEndpoints.authLogin,
      ApiEndpoints.authRefresh,
      ApiEndpoints.authLogout,
      ApiEndpoints.authMe,
      ApiEndpoints.bills,
      ApiEndpoints.billsExtract,
      ApiEndpoints.billsConfirm,
    ];

    expect(endpoints.toSet(), hasLength(endpoints.length));
    for (final String path in endpoints) {
      expect(path, startsWith('/'));
      expect(path, isNot(endsWith('/')));
    }
  });

  test('the three bill endpoints share the /bills resource', () {
    expect(ApiEndpoints.bills, '/bills');
    expect(ApiEndpoints.billsExtract, '/bills/extract');
    expect(ApiEndpoints.billsConfirm, '/bills/confirm');
  });
}

import 'api_urls.dart';

class ProdAPIUrls implements ApiUrls {
  const ProdAPIUrls({this.baseUrl = defaultBaseUrl});

  static const String defaultBaseUrl =
      'https://billing-software-backend-wip4.onrender.com';

  static const String prefix = '';

  @override
  final String baseUrl;

  @override
  Uri get baseUri => Uri.parse(baseUrl);

  @override
  String get authRegister => '/auth/register';

  @override
  String get authLogin => '/auth/login';

  @override
  String get authRefresh => '/auth/refresh';

  @override
  String get authLogout => '/auth/logout';

  @override
  String get authMe => '/auth/me';

  @override
  String get bills => '/bills';

  @override
  String get billsExtract => '/bills/extract';

  @override
  String get billsConfirm => '/bills/confirm';

  @override
  String get account => '/account';

  @override
  String get accountBalance => '/account/balance';
}

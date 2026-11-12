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
  String get authRegister => '$defaultBaseUrl/auth/register';

  @override
  String get authLogin => '$defaultBaseUrl/auth/login';

  @override
  String get authRefresh => '$defaultBaseUrl/auth/refresh';

  @override
  String get authLogout => '$defaultBaseUrl/auth/logout';

  @override
  String get authMe => '$defaultBaseUrl/auth/me';

  @override
  String get bills => '$defaultBaseUrl/bills';

  @override
  String get billsExtract => '$defaultBaseUrl/bills/extract';

  @override
  String get billsConfirm => '$defaultBaseUrl/bills/confirm';
}

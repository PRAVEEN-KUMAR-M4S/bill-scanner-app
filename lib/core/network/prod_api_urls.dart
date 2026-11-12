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
  String get authRegister => '$prefix/auth/register';

  @override
  String get authLogin => '$prefix/auth/login';

  @override
  String get authRefresh => '$prefix/auth/refresh';

  @override
  String get authLogout => '$prefix/auth/logout';

  @override
  String get authMe => '$prefix/auth/me';

  @override
  String get bills => '$prefix/bills';

  @override
  String get billsExtract => '$prefix/bills/extract';

  @override
  String get billsConfirm => '$prefix/bills/confirm';
}

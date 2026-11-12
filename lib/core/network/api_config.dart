import 'api_urls.dart';
import 'prod_api_urls.dart';

abstract final class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static final ApiUrls urls = _override.isEmpty
      ? const ProdAPIUrls()
      : ProdAPIUrls(baseUrl: _override);

  static Uri get baseUrl => urls.baseUri;
}

import 'api_config.dart';
import 'api_urls.dart';

abstract final class ApiEndpoints {
  static ApiUrls get _urls => ApiConfig.urls;

  static String get authRegister => _urls.authRegister;

  static String get authLogin => _urls.authLogin;

  static String get authRefresh => _urls.authRefresh;

  static String get authLogout => _urls.authLogout;

  static String get authMe => _urls.authMe;

  static String get bills => _urls.bills;

  static String get billsExtract => _urls.billsExtract;

  static String get billsConfirm => _urls.billsConfirm;

  static String get account => _urls.account;

  static String get accountBalance => _urls.accountBalance;
}

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_api.dart';
import '../../features/auth/data/repositories/api_auth_repository.dart';
import '../../features/auth/data/session/auth_token_store.dart';
import '../../features/auth/data/session/shared_preferences_session_storage.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/continue_as_guest.dart';
import '../../features/auth/domain/usecases/register_account.dart';
import '../../features/auth/domain/usecases/sign_in_with_email.dart';
import '../../features/auth/domain/usecases/sign_in_with_provider.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/bills/data/datasources/bill_api.dart';
import '../../features/bills/data/repositories/api_bill_repository.dart';
import '../../features/bills/data/repositories/in_memory_bill_repository.dart';
import '../../features/bills/data/repositories/session_bill_repository.dart';
import '../../features/bills/domain/entities/bill.dart';
import '../../features/bills/domain/entities/bill_problem.dart';
import '../../features/bills/domain/repositories/bill_repository.dart';
import '../../features/bills/domain/usecases/fetch_bills.dart';
import '../../features/bills/domain/usecases/save_bill.dart';
import '../../features/bills/presentation/bloc/bills_bloc.dart';
import '../../features/review/presentation/bloc/review_bloc.dart';
import '../../features/scan/data/repositories/api_scan_repository.dart';
import '../../features/scan/data/repositories/session_scan_repository.dart';
import '../../features/scan/data/repositories/simulated_scan_repository.dart';
import '../../features/scan/domain/repositories/scan_repository.dart';
import '../../features/scan/domain/usecases/capture_bill.dart';
import '../../features/scan/domain/usecases/read_photo.dart';
import '../../features/scan/presentation/bloc/scan_bloc.dart';
import '../../features/scan/presentation/camera/camera_driver.dart';
import '../../features/scan/presentation/camera/plugin_camera_driver.dart';
import '../../features/scan/presentation/camera/simulated_camera_driver.dart';
import '../network/api_config.dart';
import '../network/api_service.dart';

/// Builds every feature graph once and shares the repositories between them.
///
/// `AppDependencies.create()` is what `main()` uses: it opens
/// SharedPreferences, restores the saved session, and points auth, bills and
/// the scanner at the API.
///
/// The synchronous factory exists for tests and previews: injectable
/// repositories default to the in-memory/simulated pair, so a widget test never
/// needs a network, a plugin or a saved session.
///
/// Pages only ever receive blocs, never these repositories.
final class AppDependencies {
  factory AppDependencies({
    AuthRepository? authRepository,
    BillRepository? billRepository,
    ScanRepository? scanRepository,
    CameraDriver Function()? createCamera,
    AppUser? restoredUser,
  }) {
    final AuthTokenStore tokens = AuthTokenStore();
    final BillRepository bills = billRepository ?? InMemoryBillRepository();

    return AppDependencies._(
      authRepository: authRepository ?? _apiAuthRepository(tokens),
      billRepository: bills,
      scanRepository: scanRepository ?? SimulatedScanRepository(),
      createCamera: createCamera ?? SimulatedCameraDriver.new,
      restoredUser: restoredUser,
    );
  }

  AppDependencies._({
    required AuthRepository authRepository,
    required BillRepository billRepository,
    required ScanRepository scanRepository,
    required CameraDriver Function() createCamera,
    AppUser? restoredUser,
  }) : _authRepository = authRepository,
       _billRepository = billRepository,
       _scanRepository = scanRepository,
       _createCamera = createCamera,
       _restoredUser = restoredUser;

  /// Production graph: persisted session, API auth, API bills, real scanner.
  static Future<AppDependencies> create() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AuthTokenStore tokens = AuthTokenStore(
      storage: SharedPreferencesSessionStorage(preferences),
    );
    await tokens.restore();

    final ApiService api = _apiFor(tokens);
    final ApiAuthRepository auth = ApiAuthRepository(
      authApi: AuthApi(api),
      tokens: tokens,
    );
    final AppUser? restoredUser = await auth.restoreSession();
    final SessionBillRepository bills = SessionBillRepository(
      signedIn: ApiBillRepository(billApi: BillApi(api)),
      guest: InMemoryBillRepository(),
      hasSession: () => tokens.hasSession,
    );

    return AppDependencies._(
      authRepository: auth,
      billRepository: bills,
      scanRepository: SessionScanRepository(
        signedIn: ApiScanRepository(billRepository: bills),
        guest: SimulatedScanRepository(),
        hasSession: () => tokens.hasSession,
      ),
      createCamera: PluginCameraDriver.new,
      restoredUser: restoredUser,
    );
  }

  final AuthRepository _authRepository;
  final BillRepository _billRepository;
  final ScanRepository _scanRepository;
  final CameraDriver Function() _createCamera;
  final AppUser? _restoredUser;

  /// True when a previous launch left a session; the app then starts on the
  /// shell instead of the welcome page.
  bool get hasRestoredSession => _restoredUser != null;

  /// Demo bill handed to the add-bill screen's "Just looking around?" shortcut.
  Bill get sampleBill => _scanRepository.sampleBill;

  AuthBloc createAuthBloc() {
    return AuthBloc(
      signInWithEmail: SignInWithEmail(_authRepository),
      registerAccount: RegisterAccount(_authRepository),
      signInWithProvider: SignInWithProvider(_authRepository),
      continueAsGuest: ContinueAsGuest(_authRepository),
      signOut: SignOut(_authRepository),
      restoredUser: _restoredUser,
    );
  }

  BillsBloc createBillsBloc() {
    return BillsBloc(fetchBills: FetchBills(_billRepository));
  }

  /// A fresh camera per screen: opening the camera screen asks for access,
  /// closing it releases the preview.
  ScanBloc createScanBloc() {
    return ScanBloc(
      captureBill: CaptureBill(_scanRepository),
      readPhoto: ReadPhoto(_scanRepository),
      camera: _createCamera(),
    );
  }

  ReviewBloc createReviewBloc({
    required Bill bill,
    List<BillProblem> problems = const <BillProblem>[],
  }) {
    return ReviewBloc(
      bill: bill,
      problems: problems,
      saveBill: SaveBill(_billRepository),
    );
  }

  static ApiService _apiFor(AuthTokenStore tokens) {
    return ApiService(
      baseUrl: ApiConfig.baseUrl,
      accessToken: () async => tokens.accessToken,
    );
  }

  static AuthRepository _apiAuthRepository(AuthTokenStore tokens) {
    return ApiAuthRepository(authApi: AuthApi(_apiFor(tokens)), tokens: tokens);
  }
}

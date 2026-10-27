import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/session/auth_session_storage.dart';
import '../../features/auth/data/session/auth_session_store.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/continue_as_guest.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/domain/usecases/register.dart';
import '../../features/auth/domain/usecases/sign_in_with_provider.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/bills/data/datasources/bill_remote_datasource.dart';
import '../../features/bills/data/repositories/bill_repository_impl.dart';
import '../../features/bills/data/sample_bill.dart';
import '../../features/bills/domain/entities/bill.dart';
import '../../features/bills/domain/entities/bill_problem.dart';
import '../../features/bills/domain/repositories/bill_repository.dart';
import '../../features/bills/domain/usecases/fetch_bills.dart';
import '../../features/bills/domain/usecases/save_bill.dart';
import '../../features/bills/presentation/bloc/bills_bloc.dart';
import '../../features/review/presentation/bloc/review_bloc.dart';
import '../../features/scan/data/repositories/scan_repository_impl.dart';
import '../../features/scan/domain/repositories/scan_repository.dart';
import '../../features/scan/domain/usecases/capture_bill.dart';
import '../../features/scan/domain/usecases/read_photo.dart';
import '../../features/scan/presentation/bloc/scan_bloc.dart';
import '../../features/scan/presentation/camera/camera_driver.dart';
import '../../features/scan/presentation/camera/plugin_camera_driver.dart';
import '../database/app_database.dart';
import '../network/api_config.dart';
import '../network/api_service.dart';

/// Builds every feature graph once and shares the repositories between them.
///
/// `AppDependencies.create()` is what `main()` uses: it opens SharedPreferences
/// and the SQLite database, restores the saved session, and points auth, bills
/// and the scanner at the API.
///
/// The synchronous factory exists for tests and previews: callers pass the
/// implementations they need, so a widget test can use in-memory stand-ins
/// without a network, a plugin or a saved session.
///
/// Pages only ever receive blocs, never these repositories.
final class AppDependencies {
  factory AppDependencies({
    required AuthRepository authRepository,
    required BillRepository billRepository,
    required ScanRepository scanRepository,
    required CameraDriver Function() createCamera,
    User? restoredUser,
  }) {
    return AppDependencies._(
      authRepository: authRepository,
      billRepository: billRepository,
      scanRepository: scanRepository,
      createCamera: createCamera,
      restoredUser: restoredUser,
    );
  }

  AppDependencies._({
    required AuthRepository authRepository,
    required BillRepository billRepository,
    required ScanRepository scanRepository,
    required CameraDriver Function() createCamera,
    User? restoredUser,
  }) : _authRepository = authRepository,
       _billRepository = billRepository,
       _scanRepository = scanRepository,
       _createCamera = createCamera,
       _restoredUser = restoredUser;

  /// Production graph: persisted session, API auth, API bills with the SQLite
  /// cache, real scanner.
  static Future<AppDependencies> create() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final AuthSessionStore session = AuthSessionStore(
      storage: SharedPreferencesAuthSessionStorage(preferences),
    );
    await session.restore();

    final ApiService api = _apiFor(session);
    final AuthRepositoryImpl auth = AuthRepositoryImpl(
      remote: AuthRemoteDataSource(api),
      session: session,
    );
    final User? restoredUser = await auth.restoreSession();

    // One database backs the signed-in cache and the guest's device-only
    // bills, partitioned by owner id.
    final AppDatabase? database = await AppDatabase.open();
    final BillRepositoryImpl bills = BillRepositoryImpl(
      remote: BillRemoteDataSource(api),
      database: database,
      ownerId: () =>
          session.hasSession ? (session.user?.id ?? 'account') : 'guest',
      hasSession: () => session.hasSession,
      seed: buildSampleBill(DateTime.now()),
    );

    return AppDependencies._(
      authRepository: auth,
      billRepository: bills,
      scanRepository: ScanRepositoryImpl(
        bills: bills,
        hasSession: () => session.hasSession,
      ),
      createCamera: PluginCameraDriver.new,
      restoredUser: restoredUser,
    );
  }

  final AuthRepository _authRepository;
  final BillRepository _billRepository;
  final ScanRepository _scanRepository;
  final CameraDriver Function() _createCamera;
  final User? _restoredUser;

  /// True when a previous launch left a session; the app then starts on the
  /// shell instead of the welcome page.
  bool get hasRestoredSession => _restoredUser != null;

  /// Demo bill handed to the add-bill screen's "Just looking around?" shortcut.
  Bill get sampleBill => _scanRepository.sampleBill;

  AuthBloc createAuthBloc() {
    return AuthBloc(
      login: Login(_authRepository),
      register: Register(_authRepository),
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

  static ApiService _apiFor(AuthSessionStore session) {
    return ApiService(
      baseUrl: ApiConfig.baseUrl,
      accessToken: () async => session.accessToken,
    );
  }
}

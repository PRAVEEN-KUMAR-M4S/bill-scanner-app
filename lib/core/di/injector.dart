import '../../features/auth/data/repositories/in_memory_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/continue_as_guest.dart';
import '../../features/auth/domain/usecases/register_account.dart';
import '../../features/auth/domain/usecases/sign_in_with_email.dart';
import '../../features/auth/domain/usecases/sign_in_with_provider.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/bills/data/repositories/in_memory_bill_repository.dart';
import '../../features/bills/domain/entities/bill.dart';
import '../../features/bills/domain/repositories/bill_repository.dart';
import '../../features/bills/domain/usecases/fetch_bills.dart';
import '../../features/bills/domain/usecases/save_bill.dart';
import '../../features/bills/presentation/bloc/bills_bloc.dart';
import '../../features/review/presentation/bloc/review_bloc.dart';
import '../../features/scan/data/repositories/simulated_scan_repository.dart';
import '../../features/scan/domain/repositories/scan_repository.dart';
import '../../features/scan/domain/usecases/capture_bill.dart';
import '../../features/scan/presentation/bloc/scan_bloc.dart';

/// Builds every feature graph once and shares the repositories between them.
///
/// Tests inject fast fakes through the same constructor; pages only ever see
/// blocs, never these repositories.
final class AppDependencies {
  AppDependencies({
    AuthRepository? authRepository,
    BillRepository? billRepository,
    ScanRepository? scanRepository,
  }) : _authRepository = authRepository ?? InMemoryAuthRepository(),
       _billRepository = billRepository ?? InMemoryBillRepository(),
       _scanRepository = scanRepository ?? SimulatedScanRepository();

  final AuthRepository _authRepository;
  final BillRepository _billRepository;
  final ScanRepository _scanRepository;

  /// Demo bill handed to the add-bill screen's "Just looking around?" shortcut.
  Bill get sampleBill => _scanRepository.sampleBill;

  AuthBloc createAuthBloc() {
    return AuthBloc(
      signInWithEmail: SignInWithEmail(_authRepository),
      registerAccount: RegisterAccount(_authRepository),
      signInWithProvider: SignInWithProvider(_authRepository),
      continueAsGuest: ContinueAsGuest(_authRepository),
    );
  }

  BillsBloc createBillsBloc() {
    return BillsBloc(fetchBills: FetchBills(_billRepository));
  }

  ScanBloc createScanBloc() {
    return ScanBloc(captureBill: CaptureBill(_scanRepository));
  }

  ReviewBloc createReviewBloc({required Bill bill}) {
    return ReviewBloc(bill: bill, saveBill: SaveBill(_billRepository));
  }
}

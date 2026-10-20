import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injector.dart';
import 'core/navigation/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/register_page.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/bills/domain/entities/bill.dart';
import 'features/bills/presentation/bloc/bills_bloc.dart';
import 'features/review/presentation/bloc/review_bloc.dart';
import 'features/review/presentation/pages/review_page.dart';
import 'features/scan/presentation/bloc/scan_bloc.dart';
import 'features/scan/presentation/pages/add_bill_page.dart';
import 'features/scan/presentation/pages/scan_page.dart';

class BillScannerApp extends StatefulWidget {
  const BillScannerApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<BillScannerApp> createState() => _BillScannerAppState();
}

class _BillScannerAppState extends State<BillScannerApp> {
  late final AuthBloc _authBloc = widget.dependencies.createAuthBloc();
  late final BillsBloc _billsBloc = widget.dependencies.createBillsBloc();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void dispose() {
    _authBloc.close();
    _billsBloc.close();
    super.dispose();
  }

  /// Single place that reacts to auth outcomes: success replaces the stack with
  /// the shell, failures surface as a snack bar.
  void _onAuthStateChanged(BuildContext context, AuthState state) {
    switch (state) {
      case AuthAuthenticated():
        // Keep the landing page as the root so signing out can return to it.
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppShell.routeName,
          ModalRoute.withName(WelcomePage.routeName),
        );
      case AuthError(:final String message):
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      case AuthInitial():
      case AuthLoading():
        break;
    }
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AddBillPage.routeName:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => AddBillPage(
            sampleBill: widget.dependencies.sampleBill,
          ),
        );
      case ScanPage.routeName:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider<ScanBloc>(
            create: (_) => widget.dependencies.createScanBloc(),
            child: const ScanPage(),
          ),
        );
      case ReviewPage.routeName:
        final Bill bill = settings.arguments! as Bill;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => BlocProvider<ReviewBloc>(
            create: (_) => widget.dependencies.createReviewBloc(bill: bill),
            child: const ReviewPage(),
          ),
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<BillsBloc>.value(value: _billsBloc),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: _onAuthStateChanged,
        child: MaterialApp(
          title: 'BillScan AI',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          scaffoldMessengerKey: _messengerKey,
          theme: AppTheme.light(),
          initialRoute: WelcomePage.routeName,
          routes: <String, WidgetBuilder>{
            WelcomePage.routeName: (_) => const WelcomePage(),
            SignInPage.routeName: (_) => const SignInPage(),
            RegisterPage.routeName: (_) => const RegisterPage(),
            AppShell.routeName: (_) => const AppShell(),
          },
          onGenerateRoute: _onGenerateRoute,
        ),
      ),
    );
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/failures/auth_failure.dart';
import '../../domain/usecases/continue_as_guest.dart';
import '../../domain/usecases/register_account.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_provider.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required SignInWithEmail signInWithEmail,
    required RegisterAccount registerAccount,
    required SignInWithProvider signInWithProvider,
    required ContinueAsGuest continueAsGuest,
  })  : _signInWithEmail = signInWithEmail,
        _registerAccount = registerAccount,
        _signInWithProvider = signInWithProvider,
        _continueAsGuest = continueAsGuest,
        super(const AuthInitial()) {
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthProviderSignInRequested>(_onProviderSignInRequested);
    on<AuthGuestSignInRequested>(_onGuestSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final SignInWithEmail _signInWithEmail;
  final RegisterAccount _registerAccount;
  final SignInWithProvider _signInWithProvider;
  final ContinueAsGuest _continueAsGuest;

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) {
    return _run(
      emit,
      () => _signInWithEmail(email: event.email, password: event.password),
    );
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) {
    return _run(
      emit,
      () => _registerAccount(
        name: event.name,
        email: event.email,
        password: event.password,
      ),
    );
  }

  Future<void> _onProviderSignInRequested(
    AuthProviderSignInRequested event,
    Emitter<AuthState> emit,
  ) {
    return _run(emit, () => _signInWithProvider(event.provider));
  }

  Future<void> _onGuestSignInRequested(
    AuthGuestSignInRequested event,
    Emitter<AuthState> emit,
  ) {
    return _run(emit, _continueAsGuest.call);
  }

  void _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthInitial());
  }

  Future<void> _run(
    Emitter<AuthState> emit,
    Future<AppUser> Function() request,
  ) async {
    emit(const AuthLoading());
    try {
      emit(AuthAuthenticated(await request()));
    } on AuthFailure catch (failure) {
      emit(AuthError(failure.message));
    }
  }
}

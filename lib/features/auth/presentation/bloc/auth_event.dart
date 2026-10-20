import 'package:equatable/equatable.dart';

import '../../domain/entities/auth_provider.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => <Object?>[email, password];
}

final class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  @override
  List<Object?> get props => <Object?>[name, email, password];
}

final class AuthProviderSignInRequested extends AuthEvent {
  const AuthProviderSignInRequested(this.provider);

  final AuthProvider provider;

  @override
  List<Object?> get props => <Object?>[provider];
}

final class AuthGuestSignInRequested extends AuthEvent {
  const AuthGuestSignInRequested();
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

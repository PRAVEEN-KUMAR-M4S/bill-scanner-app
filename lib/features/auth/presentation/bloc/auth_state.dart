import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => const <Object?>[];
}

/// Nothing submitted yet.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A sign-in, registration or social request is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A user is signed in.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final User user;

  @override
  List<Object?> get props => <Object?>[user];
}

/// The last request failed with a user-facing [message].
final class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

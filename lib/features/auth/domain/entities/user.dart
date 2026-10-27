import 'package:equatable/equatable.dart';

/// The signed-in identity. Guests have an empty [email].
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.isGuest = false,
  });

  final String id;
  final String name;
  final String email;
  final bool isGuest;

  @override
  List<Object?> get props => <Object?>[id, name, email, isGuest];
}

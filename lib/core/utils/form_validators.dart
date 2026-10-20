/// Validators shared by the app's forms.
abstract final class FormValidators {
  static String? email(String? value) {
    final String email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    final RegExp pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(email)) return 'Enter a valid email address';
    return null;
  }

  static String? required(String? value, {String message = 'This field is required'}) {
    if ((value ?? '').trim().isEmpty) return message;
    return null;
  }

  static String? password(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Use at least 6 characters';
    return null;
  }
}

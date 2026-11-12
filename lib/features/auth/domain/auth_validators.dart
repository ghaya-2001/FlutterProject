/// Form validators for the auth screens. Each returns an error message, or
/// null when the value is valid (the `TextFormField.validator` contract).
library;

/// Firebase Auth rejects shorter passwords.
const minPasswordLength = 6;

const maxDisplayNameLength = 40;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Enter your email.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

/// Password field of the Login screen: only checks that it is filled in.
String? validateLoginPassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter your password.';
  }
  return null;
}

/// New password (Register, Change password).
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Enter a password.';
  }
  if (password.length < minPasswordLength) {
    return 'Use at least $minPasswordLength characters.';
  }
  if (!password.contains(RegExp(r'[A-Za-z]')) ||
      !password.contains(RegExp(r'[0-9]'))) {
    return 'Use at least one letter and one number.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Confirm your password.';
  }
  if (value != password) {
    return 'Passwords do not match.';
  }
  return null;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Enter your name.';
  }
  if (name.length > maxDisplayNameLength) {
    return 'Use at most $maxDisplayNameLength characters.';
  }
  return null;
}

/// Name of the business (restaurant accounts).
String? validateBusinessName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Enter the name of your restaurant.';
  }
  if (name.length > maxDisplayNameLength) {
    return 'Use at most $maxDisplayNameLength characters.';
  }
  return null;
}

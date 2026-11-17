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

/// One requirement of a new password. The checklist under the password
/// fields (Register, Change password) shows [label] and ticks it when
/// [isMetBy] is true; [validateNewPassword] returns [error] for the first
/// rule that fails, so the checklist and the validator never disagree.
class PasswordRule {
  const PasswordRule({
    required this.id,
    required this.label,
    required this.error,
    required this.isMetBy,
  });

  /// Stable id, used in widget keys (`password-rule-<id>`).
  final String id;
  final String label;
  final String error;
  final bool Function(String password) isMetBy;
}

final _letterPattern = RegExp(r'[A-Za-z]');
final _digitPattern = RegExp(r'[0-9]');

/// Every rule a new password must follow, in the order they are shown.
final List<PasswordRule> passwordRules = [
  PasswordRule(
    id: 'length',
    label: 'At least $minPasswordLength characters',
    error: 'Use at least $minPasswordLength characters.',
    isMetBy: (password) => password.length >= minPasswordLength,
  ),
  PasswordRule(
    id: 'letter',
    label: 'At least one letter',
    error: 'Use at least one letter.',
    isMetBy: (password) => password.contains(_letterPattern),
  ),
  PasswordRule(
    id: 'number',
    label: 'At least one number',
    error: 'Use at least one number.',
    isMetBy: (password) => password.contains(_digitPattern),
  ),
];

/// New password (Register, Change password).
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Enter a password.';
  }
  for (final rule in passwordRules) {
    if (!rule.isMetBy(password)) {
      return rule.error;
    }
  }
  return null;
}

/// New password on the Change password screen: the same rules as
/// [validateNewPassword], and it must differ from [currentPassword].
String? validateChangedPassword(String? value, String currentPassword) {
  final error = validateNewPassword(value);
  if (error != null) {
    return error;
  }
  if (value == currentPassword) {
    return 'Choose a password different from your current one.';
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

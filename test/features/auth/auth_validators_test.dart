import 'package:flutter_test/flutter_test.dart';
import 'package:foodsaver/features/auth/domain/auth_failure.dart';
import 'package:foodsaver/features/auth/domain/auth_validators.dart';

void main() {
  group('validateEmail', () {
    test('accepts a valid address, ignoring spaces around it', () {
      expect(validateEmail('maya@example.com'), isNull);
      expect(validateEmail('  maya@example.com '), isNull);
    });

    test('rejects empty and malformed addresses', () {
      expect(validateEmail(null), 'Enter your email.');
      expect(validateEmail('   '), 'Enter your email.');
      for (final email in ['maya', 'maya@', 'maya@example', 'ma ya@x.com']) {
        expect(validateEmail(email), 'Enter a valid email address.');
      }
    });
  });

  test('validateLoginPassword only requires a value', () {
    expect(validateLoginPassword(''), 'Enter your password.');
    expect(validateLoginPassword('a'), isNull);
  });

  group('validateNewPassword', () {
    test('requires 6 characters with a letter and a number', () {
      expect(validateNewPassword(''), 'Enter a password.');
      expect(validateNewPassword('ab1'), 'Use at least 6 characters.');
      expect(
        validateNewPassword('abcdef'),
        'Use at least one letter and one number.',
      );
      expect(
        validateNewPassword('123456'),
        'Use at least one letter and one number.',
      );
      expect(validateNewPassword('abc123'), isNull);
    });
  });

  test('validatePasswordConfirmation must match the password', () {
    expect(
      validatePasswordConfirmation('', 'abc123'),
      'Confirm your password.',
    );
    expect(
      validatePasswordConfirmation('abc124', 'abc123'),
      'Passwords do not match.',
    );
    expect(validatePasswordConfirmation('abc123', 'abc123'), isNull);
  });

  test('validateDisplayName requires 1 to 40 characters', () {
    expect(validateDisplayName('  '), 'Enter your name.');
    expect(validateDisplayName('Maya'), isNull);
    expect(validateDisplayName('a' * 41), 'Use at most 40 characters.');
  });

  group('authErrorMessage', () {
    test('uses the same message for every wrong-credentials code', () {
      const codes = [
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
      ];
      for (final code in codes) {
        expect(authErrorMessage(code), 'Wrong email or password.');
      }
    });

    test('has specific messages for common errors', () {
      expect(
        authErrorMessage('email-already-in-use'),
        'An account already exists with this email.',
      );
      expect(
        authErrorMessage('network-request-failed'),
        contains('No internet connection'),
      );
    });

    test('falls back to a generic message', () {
      expect(
        AuthFailure('something-new').message,
        'Something went wrong. Please try again.',
      );
    });
  });
}

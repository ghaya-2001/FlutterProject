/// Error thrown by the auth module, with a message ready to show the user.
class AuthFailure implements Exception {
  AuthFailure(this.code) : message = authErrorMessage(code);

  /// Firebase Auth error code, e.g. `wrong-password`.
  final String code;
  final String message;

  @override
  String toString() => 'AuthFailure($code): $message';
}

/// English message for a Firebase Auth error [code].
String authErrorMessage(String code) {
  switch (code) {
    case 'invalid-email':
      return 'This email address is not valid.';
    case 'user-disabled':
      return 'This account has been disabled.';
    // Recent Firebase versions return `invalid-credential` for both, so the
    // app doesn't reveal which emails have an account.
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Wrong email or password.';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'weak-password':
      return 'This password is too weak. Use at least 6 characters.';
    case 'requires-recent-login':
      return 'For your security, please enter your password again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'No internet connection. Check your network and try again.';
    case 'operation-not-allowed':
      return 'Email sign-in is not enabled for this app yet.';
    case 'not-signed-in':
      return 'You are not signed in.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

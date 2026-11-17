import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';

/// Codes Firebase returns when the current password is wrong.
const _wrongPasswordCodes = {
  'wrong-password',
  'invalid-credential',
  'invalid-login-credentials',
};

/// Change password: the current password, then the new one twice, with the
/// live [PasswordChecklist]. Firebase checks the current password again
/// (reauthentication) before it accepts the new one.
///
/// Pops with the message to show (`pop<String>`). "Forgot your current
/// password?" emails a reset link to the account's address instead.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.auth});

  /// Defaults to [AuthRepository.instance]; injectable for tests.
  final AuthRepository? auth;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _resetSent = false;

  AuthRepository get _auth => widget.auth ?? AuthRepository.instance;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (mounted) {
        Navigator.of(context).pop<String>('Password changed');
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = _wrongPasswordCodes.contains(failure.code)
              ? 'Your current password is incorrect.'
              : failure.message;
        });
      }
    }
  }

  Future<void> _sendResetLink() async {
    final email = _auth.currentUser?.email;
    if (email == null) {
      return;
    }
    setState(() => _error = null);
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) {
        setState(() => _resetSent = true);
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() => _error = failure.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ScreenHeader(title: 'Change password'),
                const SizedBox(height: 8),
                const Text(
                  'Enter your current password, then choose a new one.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                KeyedSubtree(
                  key: const ValueKey('change-password-current'),
                  child: PasswordField(
                    controller: _currentController,
                    label: 'Current password',
                    validator: validateLoginPassword,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('change-password-forgot'),
                    onPressed: email == null || _loading
                        ? null
                        : _sendResetLink,
                    child: const Text(
                      'Forgot your current password?',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (_resetSent)
                  Container(
                    key: const ValueKey('change-password-reset-sent'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'We sent a reset link to $email. Open it to choose a '
                      'new password, then sign in with it.',
                      style: const TextStyle(
                        color: Color(0xFF1B1B1B),
                        height: 1.4,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                KeyedSubtree(
                  key: const ValueKey('change-password-new'),
                  child: PasswordField(
                    controller: _newController,
                    label: 'New password',
                    validator: (value) =>
                        validateChangedPassword(value, _currentController.text),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: const ValueKey('change-password-confirm'),
                  child: PasswordField(
                    controller: _confirmController,
                    label: 'Confirm new password',
                    validator: (value) => validatePasswordConfirmation(
                      value,
                      _newController.text,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 12),
                PasswordChecklist(
                  password: _newController,
                  currentPassword: _currentController,
                  confirmation: _confirmController,
                ),
                const SizedBox(height: 24),
                FormError(_error),
                PrimaryButton(
                  key: const ValueKey('change-password-submit'),
                  label: 'Change password',
                  loading: _loading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

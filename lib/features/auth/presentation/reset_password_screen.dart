import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_validators.dart';
import 'widgets/auth_widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, this.repository, this.initialEmail});

  /// Defaults to [AuthRepository.instance]; injectable for tests.
  final AuthRepository? repository;

  /// Email already typed on the Login screen.
  final String? initialEmail;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail?.trim(),
  );
  bool _loading = false;
  bool _sent = false;
  String? _error;

  AuthRepository get _auth => widget.repository ?? AuthRepository.instance;

  @override
  void dispose() {
    _emailController.dispose();
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
      await _auth.sendPasswordReset(_emailController.text);
      if (mounted) {
        setState(() {
          _loading = false;
          _sent = true;
        });
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: const Color(0xFF1B1B1B),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reset password',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email and we will send you a link to choose a new password.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey('reset-email-field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: validateEmail,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: authInputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 24),
                FormError(_error),
                if (_sent)
                  Container(
                    key: const ValueKey('reset-sent-message'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'If an account uses this email, a reset link is on its way. Check your inbox and spam folder.',
                      style: TextStyle(color: Color(0xFF1B1B1B), height: 1.4),
                    ),
                  ),
                PrimaryButton(
                  key: const ValueKey('reset-submit-button'),
                  label: _sent ? 'Send again' : 'Send reset link',
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

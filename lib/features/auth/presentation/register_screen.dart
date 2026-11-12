import 'package:flutter/material.dart';

import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_role.dart';
import '../../roles/presentation/role_home.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_validators.dart';
import 'widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.repository, this.profiles});

  /// Defaults to [AuthRepository.instance]; injectable for tests.
  final AuthRepository? repository;

  /// Defaults to [UserProfileRepository.instance]; injectable for tests.
  final UserProfileRepository? profiles;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _businessController = TextEditingController();
  UserRole _role = UserRole.user;
  bool _loading = false;
  String? _error;

  AuthRepository get _auth => widget.repository ?? AuthRepository.instance;
  UserProfileRepository get _profiles =>
      widget.profiles ?? UserProfileRepository.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _businessController.dispose();
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
      // The role is fixed at sign-up, so tell the profile before the account exists.
      _profiles.prepareSignUp(
        role: _role,
        businessName: _businessController.text,
      );
      await _auth.signUp(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      // The email is only a reminder: failing to send it must not stop sign-up.
      try {
        await _auth.sendEmailVerification();
      } catch (_) {}
      await _profiles.whenReady();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => RoleHome(profiles: _profiles)),
        (route) => false,
      );
    } on AuthFailure catch (failure) {
      _profiles.cancelSignUp();
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
                  'Create account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join Food Saver and waste less food',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SegmentedButton<UserRole>(
                  key: const ValueKey('register-role-selector'),
                  segments: [
                    for (final role in UserRole.selfRegistered)
                      ButtonSegment(value: role, label: Text(role.label)),
                  ],
                  selected: {_role},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setState(() => _role = selection.first),
                ),
                const SizedBox(height: 18),
                if (_role == UserRole.restaurant) ...[
                  TextFormField(
                    key: const ValueKey('register-business-field'),
                    controller: _businessController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: validateBusinessName,
                    decoration: authInputDecoration(
                      label: 'Restaurant name',
                      icon: Icons.storefront_outlined,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                TextFormField(
                  key: const ValueKey('register-name-field'),
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: validateDisplayName,
                  decoration: authInputDecoration(
                    label: _role == UserRole.restaurant ? 'Your name' : 'Name',
                    icon: Icons.person_outline_rounded,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('register-email-field'),
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: validateEmail,
                  decoration: authInputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: const ValueKey('register-password-field'),
                  child: PasswordField(
                    controller: _passwordController,
                    validator: validateNewPassword,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: const ValueKey('register-confirm-field'),
                  child: PasswordField(
                    controller: _confirmController,
                    label: 'Confirm password',
                    validator: (value) => validatePasswordConfirmation(
                      value,
                      _passwordController.text,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 28),
                FormError(_error),
                PrimaryButton(
                  key: const ValueKey('register-submit-button'),
                  label: 'Create account',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account?',
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

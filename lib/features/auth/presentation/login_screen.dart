import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../profile/data/user_profile_repository.dart';
import '../../roles/presentation/role_home.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/auth_validators.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.repository, this.profiles});

  /// Defaults to [AuthRepository.instance]; injectable for tests.
  final AuthRepository? repository;

  /// Defaults to [UserProfileRepository.instance]; injectable for tests.
  final UserProfileRepository? profiles;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  AuthRepository get _auth => widget.repository ?? AuthRepository.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      await _auth.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // The role decides the start screen, so wait for the profile.
      await (widget.profiles ?? UserProfileRepository.instance).whenReady();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => RoleHome(profiles: widget.profiles),
        ),
        (route) => false,
      );
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
                Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/animations/food_saver.json',
                        width: 180,
                        height: 180,
                        fit: BoxFit.contain,
                        repeat: true,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.eco_rounded,
                            size: 110,
                            color: Color(0xFF2E7D32),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Continue with your food-saving journey',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  key: const ValueKey('login-email-field'),
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
                  key: const ValueKey('login-password-field'),
                  child: PasswordField(
                    controller: _passwordController,
                    validator: validateLoginPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('login-forgot-button'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ResetPasswordScreen(
                            repository: widget.repository,
                            initialEmail: _emailController.text,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FormError(_error),
                PrimaryButton(
                  key: const ValueKey('login-submit-button'),
                  label: 'Log In',
                  loading: _loading,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      key: const ValueKey('login-signup-button'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => RegisterScreen(
                              repository: widget.repository,
                              profiles: widget.profiles,
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Sign up',
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../profile/data/user_profile_repository.dart';
import '../../roles/presentation/role_home.dart';
import '../../welcome/presentation/welcome_screen.dart';
import '../data/auth_repository.dart';

/// First screen: waits for Firebase to say whether someone is signed in, then
/// opens Home (signed in) or Welcome (signed out).
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.repository,
    this.profiles,
    this.minimumDuration = const Duration(milliseconds: 1500),
  });

  /// Defaults to [AuthRepository.instance]; injectable for tests.
  final AuthRepository? repository;

  /// Defaults to [UserProfileRepository.instance]; injectable for tests.
  final UserProfileRepository? profiles;

  /// How long the logo stays at least.
  final Duration minimumDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _minimumElapsed = false;
  bool _left = false;

  AuthRepository get _auth => widget.repository ?? AuthRepository.instance;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_route);
    _timer = Timer(widget.minimumDuration, () {
      _minimumElapsed = true;
      _route();
    });
  }

  void _route() {
    if (_left || !mounted || !_minimumElapsed || _auth.isLoading) {
      return;
    }
    _left = true;
    _open();
  }

  Future<void> _open() async {
    final signedIn = _auth.isSignedIn;
    if (signedIn) {
      // The role decides the start screen, so wait for the profile.
      await (widget.profiles ?? UserProfileRepository.instance).whenReady();
    }
    if (!mounted) {
      return;
    }
    final next = signedIn
        ? RoleHome(profiles: widget.profiles)
        : const WelcomeScreen();
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (context) => next));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth.removeListener(_route);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('splash-screen'),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/animations/food_saver.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.eco_rounded,
                size: 120,
                color: Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Food Saver',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

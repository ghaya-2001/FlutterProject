import 'package:flutter/material.dart';

import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/welcome/presentation/welcome_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

class FoodSaverApp extends StatelessWidget {
  const FoodSaverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Saver',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      builder: (context, child) =>
          _AuthGate(navigatorKey: _navigatorKey, child: child!),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFFFFC107),
          surface: const Color(0xFFF5F9F3),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F9F3),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class MyApp extends FoodSaverApp {
  const MyApp({super.key}) : super();
}

/// No screen stays open without a signed-in user: if the session ends while
/// the app is open (account deleted or disabled elsewhere, expired sign-in),
/// the app returns to Welcome with no way back.
class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late bool _wasSignedIn = AuthRepository.instance.isSignedIn;

  @override
  void initState() {
    super.initState();
    AuthRepository.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final signedIn = AuthRepository.instance.isSignedIn;
    if (_wasSignedIn && !signedIn) {
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
    _wasSignedIn = signedIn;
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

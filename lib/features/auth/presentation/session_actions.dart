import 'package:flutter/material.dart';

import '../../notifications/data/notification_service.dart';
import '../../welcome/presentation/welcome_screen.dart';
import '../data/auth_repository.dart';

/// Secure logout: signs out, cancels the phone alerts of this account and
/// returns to Welcome with no way back.
Future<void> signOutAndShowWelcome(
  BuildContext context, {
  AuthRepository? auth,
}) async {
  final navigator = Navigator.of(context);
  await (auth ?? AuthRepository.instance).signOut();
  await NotificationService.instance.cancelAll();
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    (route) => false,
  );
}

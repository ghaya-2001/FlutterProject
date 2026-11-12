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

/// Asks "Log out?" and signs out if the user confirms.
Future<void> confirmAndSignOut(
  BuildContext context, {
  AuthRepository? auth,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Log out?'),
      content: const Text(
        'Are you sure you want to leave your food-saving journey?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        TextButton(
          key: const ValueKey('logout-confirm-button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'Yes, log out',
            style: TextStyle(color: Color(0xFF2E7D32)),
          ),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await signOutAndShowWelcome(context, auth: auth);
  }
}

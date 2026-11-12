import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/domain/auth_validators.dart';
import '../../auth/presentation/session_actions.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../data/user_profile_repository.dart';

/// Notifications on/off, change password and delete account.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.auth, this.profiles});

  /// Default to the app-wide instances; injectable for tests.
  final AuthRepository? auth;
  final UserProfileRepository? profiles;

  AuthRepository get _auth => auth ?? AuthRepository.instance;
  UserProfileRepository get _profiles =>
      profiles ?? UserProfileRepository.instance;

  Future<void> _changePassword(BuildContext context) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ChangePasswordDialog(auth: _auth),
    );
    if (changed == true && context.mounted) {
      showAppSnackBar(context, 'Password changed');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _DeleteAccountDialog(auth: _auth, profiles: _profiles),
    );
    if (deleted == true && context.mounted) {
      // The account is already gone: this clears the alerts and returns to Welcome.
      await signOutAndShowWelcome(context, auth: _auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ScreenHeader(title: 'Settings'),
              const SizedBox(height: 22),
              ListenableBuilder(
                listenable: _profiles,
                builder: (context, _) => _SettingsCard(
                  child: SwitchListTile(
                    key: const ValueKey('settings-notifications-switch'),
                    value: _profiles.settings.notificationsEnabled,
                    onChanged: _profiles.profile == null
                        ? null
                        : _profiles.setNotificationsEnabled,
                    activeThumbColor: const Color(0xFF2E7D32),
                    title: const Text(
                      'Notifications',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text('Expiry alerts and donation requests'),
                    secondary: const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: ListTile(
                  key: const ValueKey('settings-change-password'),
                  leading: const Icon(
                    Icons.lock_outline_rounded,
                    color: Color(0xFF2E7D32),
                  ),
                  title: const Text(
                    'Change password',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _changePassword(context),
                ),
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                child: ListTile(
                  key: const ValueKey('settings-delete-account'),
                  leading: const Icon(
                    Icons.delete_forever_outlined,
                    color: Color(0xFFC62828),
                  ),
                  title: const Text(
                    'Delete account',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  subtitle: const Text(
                    'Removes your account and all your data',
                  ),
                  onTap: () => _deleteAccount(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.auth});

  final AuthRepository auth;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;
  String? _error;

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
      await widget.auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Change password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KeyedSubtree(
                key: const ValueKey('change-password-current'),
                child: PasswordField(
                  controller: _currentController,
                  label: 'Current password',
                  validator: validateLoginPassword,
                ),
              ),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: const ValueKey('change-password-new'),
                child: PasswordField(
                  controller: _newController,
                  label: 'New password',
                  validator: validateNewPassword,
                ),
              ),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: const ValueKey('change-password-confirm'),
                child: PasswordField(
                  controller: _confirmController,
                  label: 'Confirm new password',
                  validator: (value) =>
                      validatePasswordConfirmation(value, _newController.text),
                ),
              ),
              const SizedBox(height: 14),
              FormError(_error),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        TextButton(
          key: const ValueKey('change-password-submit'),
          onPressed: _loading ? null : _submit,
          child: const Text(
            'Change',
            style: TextStyle(color: Color(0xFF2E7D32)),
          ),
        ),
      ],
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.auth, required this.profiles});

  final AuthRepository auth;
  final UserProfileRepository profiles;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
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
      // The data goes first: the security rules need the user signed in.
      await widget.auth.reauthenticate(_passwordController.text);
      await widget.profiles.deleteAllData();
      await widget.auth.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on AuthFailure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = authErrorMessage('unknown');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Delete account?'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This permanently deletes your account and all your data '
                '(fridge, lists, donations). Enter your password to confirm.',
              ),
              const SizedBox(height: 14),
              KeyedSubtree(
                key: const ValueKey('delete-account-password'),
                child: PasswordField(
                  controller: _passwordController,
                  validator: validateLoginPassword,
                ),
              ),
              const SizedBox(height: 14),
              FormError(_error),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
        ),
        TextButton(
          key: const ValueKey('delete-account-submit'),
          onPressed: _loading ? null : _submit,
          child: const Text(
            'Delete',
            style: TextStyle(color: Color(0xFFC62828)),
          ),
        ),
      ],
    );
  }
}

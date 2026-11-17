import 'package:flutter/material.dart';

import '../../domain/auth_validators.dart';

/// White rounded input used by every auth and profile form.
InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}

/// Password input with a show/hide button.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.validator,
    this.label = 'Password',
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final String label;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      decoration: authInputDecoration(
        label: widget.label,
        icon: Icons.lock_outline_rounded,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ),
    );
  }
}

/// Live list of the [passwordRules] under a new-password field; each rule is
/// ticked as soon as the typed [password] follows it.
///
/// With [currentPassword] it also checks that the new password is different
/// (Change password); with [confirmation] it checks that both fields match.
/// Rows are keyed `password-rule-<id>` (`different` and `match` for the two
/// extra checks).
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({
    super.key,
    required this.password,
    this.confirmation,
    this.currentPassword,
  });

  final TextEditingController password;
  final TextEditingController? confirmation;
  final TextEditingController? currentPassword;

  @override
  Widget build(BuildContext context) {
    final current = currentPassword;
    final confirm = confirmation;
    return ListenableBuilder(
      listenable: Listenable.merge([password, current, confirm]),
      builder: (context, _) {
        final value = password.text;
        return Container(
          key: const ValueKey('password-checklist'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final rule in passwordRules)
                _ChecklistRow(
                  id: rule.id,
                  label: rule.label,
                  met: rule.isMetBy(value),
                ),
              if (current != null)
                _ChecklistRow(
                  id: 'different',
                  label: 'Different from your current password',
                  met: value.isNotEmpty && value != current.text,
                ),
              if (confirm != null)
                _ChecklistRow(
                  id: 'match',
                  label: 'Both new passwords match',
                  met: confirm.text.isNotEmpty && confirm.text == value,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.id,
    required this.label,
    required this.met,
  });

  final String id;
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF2E7D32);
    return Semantics(
      label: '$label: ${met ? 'done' : 'not yet'}',
      excludeSemantics: true,
      child: Padding(
        key: ValueKey('password-rule-$id'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                met
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                key: ValueKey(met),
                size: 20,
                color: met ? green : Colors.black38,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: met ? green : Colors.black54,
                  fontWeight: met ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big green button that shows a spinner while [loading].
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Red message shown under a form when the server refused the request.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        message!,
        style: const TextStyle(color: Color(0xFFC62828), fontSize: 14),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AuthFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscure;
  final bool enabled;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.obscure = false,
    this.enabled = true,
    this.keyboardType,
    this.autofillHints,
  });
  /// FEATURE: UC-004, UC-005, UC-006, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Ghép TextFormField với validator, obscureText, autofill và enabled do AuthForm truyền vào.
  /// ROLE: Reusable validated form field
  /// CALLED FROM: AuthForm.build.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      validator: validator,
      enabled: enabled,
      obscureText: obscure,
      autocorrect: !obscure && keyboardType != TextInputType.emailAddress,
      enableSuggestions: !obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

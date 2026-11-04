import 'package:flutter/material.dart';
import '../widgets/auth_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  /// FEATURE: UC-004 - Register Account
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Dựng AuthForm với AuthFormKind.register từ route tương ứng.
  /// ROLE: Auth route screen
  /// CALLED FROM: appRouterProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material.
  @override
  Widget build(BuildContext context) =>
      const AuthForm(kind: AuthFormKind.register);
}

import 'package:flutter/material.dart';
import '../widgets/auth_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  /// FEATURE: UC-005 - Log In
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Dựng AuthForm với AuthFormKind.login từ route tương ứng.
  /// ROLE: Auth route screen
  /// CALLED FROM: appRouterProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material.
  @override
  Widget build(BuildContext context) =>
      const AuthForm(kind: AuthFormKind.login);
}

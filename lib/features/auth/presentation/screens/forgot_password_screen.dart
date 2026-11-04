import 'package:flutter/material.dart';
import '../widgets/auth_form.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  /// FEATURE: UC-006 - Reset Password
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Dựng AuthForm với AuthFormKind.reset từ route tương ứng.
  /// ROLE: Auth route screen
  /// CALLED FROM: appRouterProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material.
  @override
  Widget build(BuildContext context) =>
      const AuthForm(kind: AuthFormKind.reset);
}

import 'package:flutter/material.dart';
import '../widgets/auth_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthForm(kind: AuthFormKind.register);
}

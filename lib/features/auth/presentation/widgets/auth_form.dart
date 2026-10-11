import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/validators.dart';
import '../viewmodels/auth_view_model.dart';
import 'auth_form_field.dart';

enum AuthFormKind { login, register, reset }

class AuthForm extends ConsumerStatefulWidget {
  final AuthFormKind kind;
  const AuthForm({super.key, required this.kind});
  @override
  ConsumerState<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends ConsumerState<AuthForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _name = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    AuthFormKind.login => 'Sign in',
    AuthFormKind.register => 'Create account',
    AuthFormKind.reset => 'Reset password',
  };
  void _navigate(String path) {
    ref.read(authViewModelProvider.notifier).clearFeedback();
    context.go(path);
  }

  Future<void> _submit() async {
    if (ref.read(authViewModelProvider).isLoading ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final vm = ref.read(authViewModelProvider.notifier);
    switch (widget.kind) {
      case AuthFormKind.login:
        await vm.signIn(_email.text, _password.text);
      case AuthFormKind.register:
        await vm.register(_email.text, _password.text, _name.text);
      case AuthFormKind.reset:
        await vm.resetPassword(_email.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(authViewModelProvider);
    final busy = action.isLoading;
    final register = widget.kind == AuthFormKind.register;
    final reset = widget.kind == AuthFormKind.reset;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'CampusHub',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (register)
                        AuthFormField(
                          controller: _name,
                          label: 'Name',
                          validator: Validators.displayName,
                          enabled: !busy,
                          autofillHints: const [AutofillHints.name],
                        ),
                      AuthFormField(
                        controller: _email,
                        label: 'Email',
                        validator: Validators.email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                      ),
                      if (!reset)
                        AuthFormField(
                          controller: _password,
                          label: 'Password',
                          validator: register
                              ? Validators.password
                              : Validators.loginPassword,
                          obscure: true,
                          enabled: !busy,
                          autofillHints: [
                            register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                        ),
                      if (register)
                        AuthFormField(
                          controller: _confirm,
                          label: 'Confirm password',
                          validator: (value) =>
                              Validators.confirmPassword(value, _password.text),
                          obscure: true,
                          enabled: !busy,
                        ),
                      if (action.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            action.error.toString(),
                            key: const Key('auth-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (action.asData?.value != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            action.asData!.value!,
                            key: const Key('auth-success'),
                          ),
                        ),
                      FilledButton(
                        onPressed: busy ? null : _submit,
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_title),
                      ),
                      if (widget.kind == AuthFormKind.login) ...[
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _navigate(RouteNames.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _navigate(RouteNames.register),
                          child: const Text('Create an account'),
                        ),
                      ] else
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => _navigate(RouteNames.login),
                          child: const Text('Back to sign in'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

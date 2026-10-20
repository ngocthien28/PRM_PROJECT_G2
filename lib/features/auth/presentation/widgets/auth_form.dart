import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
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
    return _AuthCanvas(
      heading: register
          ? 'Make yourself at home.'
          : reset
          ? 'Let’s get you back in.'
          : 'Welcome back.',
      description: register
          ? 'Your campus story starts with an account.'
          : reset
          ? 'We will send a reset link to your email.'
          : 'Sign in to your people, your plans, and your campus.',
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                          child: CircularProgressIndicator(strokeWidth: 2),
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
                    onPressed: busy ? null : () => _navigate(RouteNames.login),
                    child: const Text('Back to sign in'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCanvas extends StatelessWidget {
  const _AuthCanvas({
    required this.heading,
    required this.description,
    required this.content,
  });
  final String heading, description;
  final Widget content;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final wide = box.maxWidth >= 1000;
          final form = SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 48 : 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: CampusColors.teal,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.hub_outlined,
                            size: 25,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'CampusHub',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(letterSpacing: -.8),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      heading,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: CampusColors.muted,
                      ),
                    ),
                    const SizedBox(height: 30),
                    content,
                    const SizedBox(height: 26),
                    const Divider(),
                    const SizedBox(height: 20),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 13,
                          color: CampusColors.muted,
                        ),
                        SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'Your campus connection starts here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CampusColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          if (!wide) return Center(child: form);
          return Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(18),
                  padding: const EdgeInsets.all(42),
                  decoration: BoxDecoration(
                    color: CampusColors.ink,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.hub_outlined,
                            color: CampusColors.gold,
                            size: 25,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'campushub',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.7,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Flexible(
                        flex: 4,
                        child: SizedBox(height: 270, child: CampusArtwork()),
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'A place to belong.\nA chance to become.',
                        style: TextStyle(
                          fontSize: 39,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.5,
                          height: 1.15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Discover your next interest, meet your next friend,\nand make the most of your campus life.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.8,
                          color: Color(0xFFB8D0C2),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'YOUR CAMPUS. YOUR PEOPLE. YOUR CHAPTER.',
                        style: TextStyle(
                          color: CampusColors.gold,
                          fontSize: 9,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: Center(child: form)),
            ],
          );
        },
      ),
    ),
  );
}

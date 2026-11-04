import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../viewmodels/auth_view_model.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});
  /// FEATURE: UC-002, UC-003, UC-004, UC-007, UC-013
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Phân biệt phiên chờ, profile thiếu/bị khóa/lỗi; mở Retry, recoverProfile và signOut phù hợp.
  /// ROLE: Session gate recovery UI
  /// CALLED FROM: appRouterProvider / sessionRedirect.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(currentUserProvider);
    final action = ref.watch(authViewModelProvider);
    final vm = ref.read(authViewModelProvider.notifier);
    final identity = auth.asData?.value;
    final missing =
        !auth.isLoading &&
        !auth.hasError &&
        identity != null &&
        !profile.isLoading &&
        !profile.hasError &&
        profile.asData?.value == null;
    final disabled =
        !profile.isLoading && profile.asData?.value?.isActive == false;
    final error = auth.hasError
        ? auth.error.toString()
        : profile.hasError
        ? profile.error is AppException &&
                  (profile.error as AppException).code == 'permission-denied'
              ? 'Your profile cannot be accessed. Sign out and sign in again. '
                    'If the problem continues, contact the project administrator.'
              : profile.error.toString()
        : disabled
        ? 'This account is disabled or unavailable. Contact the administrator.'
        : missing
        ? 'Your account has no profile yet. Retry profile setup to continue.'
        : null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('CampusHub', style: TextStyle(fontSize: 30)),
                const SizedBox(height: 24),
                if (error == null || action.isLoading)
                  const LoadingIndicator(message: 'Loading your account...'),
                if (error != null) ...[
                  Text(error, textAlign: TextAlign.center),
                  if (action.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        action.error.toString(),
                        key: const Key('auth-error'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (missing)
                    FilledButton(
                      onPressed: action.isLoading ? null : vm.recoverProfile,
                      child: const Text('Retry profile setup'),
                    ),
                  if (!disabled && !missing)
                    FilledButton(
                      onPressed: action.isLoading ? null : vm.retrySession,
                      child: const Text('Retry'),
                    ),
                  if (identity != null || auth.hasError)
                    TextButton(
                      onPressed: action.isLoading ? null : vm.signOut,
                      child: const Text('Sign out'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

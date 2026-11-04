import 'package:flutter/material.dart';
import '../errors/app_exception.dart';

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
  });
  final Object error;
  final String? message;
  final VoidCallback? onRetry;

  /// FEATURE: UC-013 - Implement Shared Loading and Error Handling
  /// MODULE: App Shell
  /// DESCRIPTION: Hiển thị AppException hoặc lỗi chung và nút Retry khi có callback.
  /// ROLE: Shared async UI
  /// CALLED FROM: ProfileScreen, EditProfileScreen hoặc AsyncValueView.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material.
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message ??
                (error is AppException
                    ? error.toString()
                    : 'Something went wrong. Please try again.'),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );
}

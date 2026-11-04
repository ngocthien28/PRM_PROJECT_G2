import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_error_view.dart';
import 'loading_indicator.dart';

/// Loading and errors take precedence over previously retained data.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.loadingMessage = 'Loading...',
  });
  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final VoidCallback? onRetry;
  final String loadingMessage;

  /// FEATURE: UC-013 - Implement Shared Loading and Error Handling
  /// MODULE: App Shell
  /// DESCRIPTION: Ưu tiên loading rồi lỗi trước retained data; dùng LoadingIndicator và AppErrorView để tránh lộ profile cũ.
  /// ROLE: Shared async UI
  /// CALLED FROM: ProfileScreen, EditProfileScreen hoặc AsyncValueView.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod.
  @override
  Widget build(BuildContext context) {
    if (value.isLoading) return LoadingIndicator(message: loadingMessage);
    if (value.hasError) {
      return AppErrorView(error: value.error!, onRetry: onRetry);
    }
    return data(value.requireValue);
  }
}

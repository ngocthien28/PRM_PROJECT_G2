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

  @override
  Widget build(BuildContext context) {
    if (value.isLoading) return LoadingIndicator(message: loadingMessage);
    if (value.hasError) {
      return AppErrorView(error: value.error!, onRetry: onRetry);
    }
    return data(value.requireValue);
  }
}

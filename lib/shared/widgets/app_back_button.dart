import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Also works when a page was opened directly without a navigation stack.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallbackLocation});

  final String fallbackLocation;

  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: App Shell
  /// DESCRIPTION: Pop navigation stack nếu có; nếu không mở fallbackLocation khi truy cập trực tiếp.
  /// ROLE: Back navigation
  /// CALLED FROM: Các màn hình dùng AppBackButton.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, go_router.
  @override
  Widget build(BuildContext context) => BackButton(
    onPressed: () {
      final router = GoRouter.of(context);
      if (router.canPop()) {
        router.pop();
      } else {
        router.go(fallbackLocation);
      }
    },
  );
}

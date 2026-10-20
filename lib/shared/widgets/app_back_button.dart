import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Also works when a page was opened directly without a navigation stack.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallbackLocation});

  final String fallbackLocation;

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

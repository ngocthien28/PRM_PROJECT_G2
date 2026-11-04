import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message = 'Loading...'});
  final String message;

  /// FEATURE: UC-013 - Implement Shared Loading and Error Handling
  /// MODULE: App Shell
  /// DESCRIPTION: Hiển thị spinner có semanticsLabel và thông điệp loading dùng chung.
  /// ROLE: Shared async UI
  /// CALLED FROM: ProfileScreen, EditProfileScreen hoặc AsyncValueView.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material.
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(semanticsLabel: message),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

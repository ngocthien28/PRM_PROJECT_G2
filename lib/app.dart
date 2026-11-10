import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/services/firebase_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/routing/route_names.dart';

final pushInitializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(firebaseInitializationProvider.future);
  final router = ref.watch(appRouterProvider);
  await NotificationService.instance.start(
    () => router.push(RouteNames.notifications),
  );
});

/// FEATURE: UC-002, UC-013
/// MODULE: App Shell
/// DESCRIPTION: Chuyển lỗi cấu hình nền tảng hoặc khởi tạo Firebase thành thông báo có thể thử lại.
/// ROLE: Bootstrap error feedback
/// CALLED FROM: CampusHubApp.build.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Flutter Material, Riverpod.
String firebaseInitializationMessage(Object error) {
  if (error is UnsupportedError &&
      error.message.toString().contains('have not been configured for')) {
    return 'Firebase has not been configured for this platform yet. '
        'Register this app in Firebase and run flutterfire configure.';
  }

  return 'Firebase could not be initialized. Check the Firebase '
      'configuration and your connection, then try again.';
}

class CampusHubApp extends ConsumerWidget {
  const CampusHubApp({super.key});

  /// FEATURE: UC-001, UC-002, UC-013
  /// MODULE: App Shell
  /// DESCRIPTION: Chờ Firebase; dựng MaterialApp.router với theme chung hoặc loading/lỗi và nút Retry.
  /// ROLE: App shell / bootstrap state
  /// CALLED FROM: Flutter widget tree.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(firebaseInitializationProvider);
    if (initialization.hasValue) {
      final push = ref.watch(pushInitializationProvider);
      if (push.hasError) {
        debugPrint('Push initialization failed: ${push.error}');
      }
    }
    return initialization.when(
      skipLoadingOnRefresh: false,
      data: (_) => MaterialApp.router(
        title: 'CampusHub',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: ref.watch(appRouterProvider),
      ),
      loading: () => MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, _) => MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('CampusHub', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 16),
                  Text(
                    firebaseInitializationMessage(error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        ref.invalidate(firebaseInitializationProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

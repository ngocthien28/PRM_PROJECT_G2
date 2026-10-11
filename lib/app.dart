import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/services/firebase_providers.dart';
import 'core/theme/app_theme.dart';

class CampusHubApp extends ConsumerWidget {
  const CampusHubApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initialization = ref.watch(firebaseInitializationProvider);
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
                  const Text(
                    'Firebase could not be initialized. Check the Firebase '
                    'configuration and your connection, then try again.',
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

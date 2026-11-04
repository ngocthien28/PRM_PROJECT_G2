import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../features/notifications/presentation/viewmodels/notification_view_model.dart';

class RoleNavigationActions extends ConsumerWidget {
  const RoleNavigationActions({super.key});

  /// FEATURE: UC-001 - Build Shared App Navigation and Theme
  /// MODULE: App Shell
  /// DESCRIPTION: Dựng nút Clubs và Notifications cùng badge chưa đọc trong header dùng chung.
  /// ROLE: Shared navigation UI
  /// CALLED FROM: HomeScreen và OrganizerDashboardScreen.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod, go_router.
  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: 'Clubs',
        onPressed: () => context.push(RouteNames.clubs),
        icon: const Icon(Icons.groups_outlined),
      ),
      IconButton(
        tooltip: 'Notifications',
        onPressed: () => context.push(RouteNames.notifications),
        icon: Badge(
          isLabelVisible: ref.watch(unreadNotificationCountProvider) > 0,
          label: Text('${ref.watch(unreadNotificationCountProvider)}'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
    ],
  );
}

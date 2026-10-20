import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';
import '../../features/notifications/presentation/viewmodels/notification_view_model.dart';

class RoleNavigationActions extends ConsumerWidget {
  const RoleNavigationActions({super.key});

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

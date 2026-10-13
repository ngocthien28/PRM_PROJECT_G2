import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routing/route_names.dart';

class RoleNavigationActions extends StatelessWidget {
  const RoleNavigationActions({super.key});

  @override
  Widget build(BuildContext context) => Row(
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
        icon: const Icon(Icons.notifications_outlined),
      ),
    ],
  );
}

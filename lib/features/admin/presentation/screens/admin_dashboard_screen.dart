import 'package:flutter/material.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Admin Dashboard'),
      actions: const [RoleNavigationActions()],
    ),
    body: const Center(child: Text('Admin moderation scaffold')),
  );
}

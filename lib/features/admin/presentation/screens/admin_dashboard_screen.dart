import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';
import '../viewmodels/admin_dashboard_view_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: const [RoleNavigationActions()],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(adminStatsProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry: $error'),
          ),
        ),
        data: (value) => GridView.count(
          padding: const EdgeInsets.all(24),
          crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 2 : 1,
          childAspectRatio: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _StatCard('Users', value.userCount, Icons.people_outline),
            _StatCard('Clubs', value.clubCount, Icons.groups_outlined),
            _StatCard('Events', value.eventCount, Icons.event_outlined),
            _StatCard(
              'Active memberships',
              value.activeMembershipCount,
              Icons.how_to_reg_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(label),
      trailing: Text(
        '$value',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    ),
  );
}

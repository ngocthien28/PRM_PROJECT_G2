import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/admin_dashboard_view_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final signingOut = ref.watch(authViewModelProvider).isLoading;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          const RoleNavigationActions(),
          IconButton(
            key: const Key('adminSignOutButton'),
            tooltip: 'Sign out',
            onPressed: signingOut
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text(
                          'You will need to sign in again to access the admin dashboard.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton.icon(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign out'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(authViewModelProvider.notifier).signOut();
                    }
                  },
            icon: signingOut
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
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

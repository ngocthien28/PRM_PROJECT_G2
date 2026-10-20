import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../viewmodels/admin_dashboard_view_model.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final counts = stats.asData?.value;
    final scale = [
      counts?.userCount ?? 0,
      counts?.clubCount ?? 0,
      counts?.eventCount ?? 0,
      counts?.activeMembershipCount ?? 0,
    ].fold<int>(1, (largest, count) => math.max(largest, count));
    final user = ref.watch(currentUserProvider).asData?.value;
    Future<void> signOut() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to access the admin dashboard.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialog, true),
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(authViewModelProvider.notifier).signOut();
      }
    }

    return CampusScaffold(
      title: 'Admin Dashboard',
      section: CampusSection.admin,
      role: 'admin',
      userName: user?.displayName ?? 'Administrator',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      onSignOut: signOut,
      signingOut: ref.watch(authViewModelProvider).isLoading,
      signOutKey: const Key('adminSignOutButton'),
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: () => ref.invalidate(adminStatsProvider),
          icon: const Icon(Icons.refresh_rounded, size: 21),
        ),
      ],
      body: CampusPage(
        children: [
          const Text(
            'CAMPUS OPERATIONS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: CampusColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'A thriving campus starts here.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 10),
          const Text(
            'Your communities, people and activity. One clear overview.',
            style: TextStyle(fontSize: 13, color: CampusColors.muted),
          ),
          const SizedBox(height: 26),
          stats.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(50),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => CampusEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Overview temporarily unavailable',
              message:
                  'We could not load campus statistics. Try refreshing your dashboard.',
              action: FilledButton.icon(
                onPressed: () => ref.invalidate(adminStatsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth >= 850
                        ? 4
                        : box.maxWidth >= 440
                        ? 2
                        : 1;
                    final width = (box.maxWidth - (columns - 1) * 16) / columns;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: _StatCard(
                            'Users',
                            value.userCount,
                            Icons.people_outline_rounded,
                            'Campus accounts',
                            const Color(0xFFE9F1FF),
                            const Color(0xFF4B74AD),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _StatCard(
                            'Active clubs',
                            value.clubCount,
                            Icons.groups_outlined,
                            'Communities open to join',
                            CampusColors.mint,
                            CampusColors.teal,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _StatCard(
                            'Events',
                            value.eventCount,
                            Icons.event_outlined,
                            'Events in the workspace',
                            const Color(0xFFFFF0D5),
                            const Color(0xFFB88226),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _StatCard(
                            'Student memberships',
                            value.activeMembershipCount,
                            Icons.how_to_reg_outlined,
                            'In active communities',
                            const Color(0xFFF1EAF6),
                            const Color(0xFF9270AE),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 26),
                LayoutBuilder(
                  builder: (context, box) {
                    final overview = Card(
                      child: Padding(
                        padding: const EdgeInsets.all(25),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeading(
                              title: 'Your campus at a glance',
                              subtitle: 'Current counts from the workspace',
                            ),
                            const SizedBox(height: 28),
                            _MetricBar(
                              'Campus accounts',
                              value.userCount,
                              scale,
                              const Color(0xFF7392BA),
                            ),
                            const SizedBox(height: 22),
                            _MetricBar(
                              'Active clubs',
                              value.clubCount,
                              scale,
                              CampusColors.teal,
                            ),
                            const SizedBox(height: 22),
                            _MetricBar(
                              'Events',
                              value.eventCount,
                              scale,
                              const Color(0xFFCFAC63),
                            ),
                            const SizedBox(height: 22),
                            _MetricBar(
                              'Student memberships',
                              value.activeMembershipCount,
                              scale,
                              const Color(0xFF9F83B7),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 15),
                            const Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: CampusColors.muted,
                                ),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Memberships count students in active clubs, not unique people.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: CampusColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                    final feature = Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: CampusColors.ink,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 130, child: CampusArtwork()),
                          const SizedBox(height: 16),
                          const Text(
                            'Make room for\nnew communities.',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                              letterSpacing: -.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Help students find their people. Create a club or refresh an existing community.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.7,
                              color: Color(0xFFB8D0C2),
                            ),
                          ),
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            onPressed: () =>
                                context.push(RouteNames.createClub),
                            style: FilledButton.styleFrom(
                              backgroundColor: CampusColors.gold,
                              foregroundColor: CampusColors.ink,
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create Club'),
                          ),
                        ],
                      ),
                    );
                    if (box.maxWidth < 760) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          overview,
                          const SizedBox(height: 18),
                          feature,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: overview),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: feature),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeading(
            title: 'Your workspace, within reach',
            subtitle: 'Jump straight to the task you need.',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth >= 780 ? 3 : 1;
              final width = (box.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: width,
                    child: _QuickAction(
                      icon: Icons.groups_outlined,
                      title: 'Club directory',
                      subtitle: 'Explore and manage communities',
                      onTap: () => context.push(RouteNames.clubs),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _QuickAction(
                      icon: Icons.notifications_outlined,
                      title: 'Your inbox',
                      subtitle: 'Keep up with your updates',
                      onTap: () => context.push(RouteNames.notifications),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _QuickAction(
                      icon: Icons.verified_user_outlined,
                      title: 'Moderation',
                      subtitle: 'Open the moderation workspace',
                      onTap: () => context.push('/admin/moderation'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
    this.label,
    this.value,
    this.icon,
    this.caption,
    this.background,
    this.color,
  );
  final String label, caption;
  final int value;
  final IconData icon;
  final Color background, color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 36,
              letterSpacing: -1,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            style: const TextStyle(fontSize: 10, color: CampusColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar(this.label, this.value, this.max, this.color);
  final String label;
  final int value, max;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: CampusColors.muted),
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(
          value: value / max,
          minHeight: 7,
          color: color,
          backgroundColor: CampusColors.canvas,
        ),
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: CampusColors.teal, size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: CampusColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 17,
              color: CampusColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

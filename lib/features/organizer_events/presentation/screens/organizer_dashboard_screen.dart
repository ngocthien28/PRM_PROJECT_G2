// CampusHub skeleton • lib/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';

import '../../../events/data/models/event_model.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/organizer_events_view_model.dart';

/// Minimal organizer entry point until the full dashboard is implemented.
class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({
    super.key,
    required this.onCreateEvent,
    required this.onManageEvents,
    required this.onEditEvent,
    this.onViewParticipants,
  });

  final VoidCallback onCreateEvent;
  final VoidCallback onManageEvents;
  final ValueChanged<EventModel> onEditEvent;
  final ValueChanged<EventModel>? onViewParticipants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(organizerEventsProvider);
    final signingOut = ref.watch(authViewModelProvider).isLoading;
    final eventCount =
        events.asData?.value
            .where((event) => event.status != EventStatus.cancelled)
            .length ??
        0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CampusHub Organizer'),
        actions: [
          const RoleNavigationActions(),
          IconButton(
            key: const Key('organizerSignOutButton'),
            tooltip: 'Sign out',
            onPressed: signingOut
                ? null
                : () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: const Text(
                          'You will need to sign in again to manage events.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Event management',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create and manage campus experiences for your community.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    key: const Key('createEventAction'),
                    onPressed: onCreateEvent,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Event'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onManageEvents,
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('View all managed events'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatCard(
              icon: Icons.event_available_outlined,
              label: 'My events',
              value: events.isLoading ? '—' : '$eventCount',
            ),
            const SizedBox(height: 24),
            Text('My events', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            events.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (_, _) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 36,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to load your events right now.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('dashboardRetryButton'),
                        onPressed: () =>
                            ref.invalidate(organizerEventsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                final activeItems = items
                    .where((event) => event.status != EventStatus.cancelled)
                    .toList();
                return activeItems.isEmpty
                    ? const _EmptyState(
                        message:
                            'No events yet. Create your first event to get started.',
                      )
                    : Column(
                        children: activeItems
                            .map(
                              (event) => Card(
                                child: ListTile(
                                  onTap: () => context.push(
                                    RouteNames.organizerEventDetail(event.id),
                                  ),
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.event_outlined),
                                  ),
                                  title: Text(event.title),
                                  subtitle: Text(event.locationName),
                                  trailing: PopupMenuButton<_EventAction>(
                                    tooltip: 'Event actions',
                                    onSelected: (action) {
                                      if (action == _EventAction.edit) {
                                        onEditEvent(event);
                                      } else if (action ==
                                          _EventAction.participants) {
                                        if (onViewParticipants != null) {
                                          onViewParticipants!(event);
                                        } else {
                                          context.push(
                                            RouteNames.organizerEventParticipants(
                                              event.id,
                                            ),
                                          );
                                        }
                                      } else {
                                        _confirmCancel(context, ref, event);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: _EventAction.edit,
                                        child: ListTile(
                                          leading: Icon(Icons.edit_outlined),
                                          title: Text('Edit'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _EventAction.participants,
                                        child: ListTile(
                                          leading: Icon(Icons.people_outline),
                                          title: Text('Participants'),
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: _EventAction.delete,
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline),
                                          title: Text('Delete event'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          '“${event.title}” will be cancelled and hidden from students.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(organizerEventActionsProvider).cancelEvent(event.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event deleted.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to delete this event.')),
        );
      }
    }
  }
}

enum _EventAction { edit, participants, delete }

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(label),
      trailing: Text(value, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.event_note_outlined, size: 36),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

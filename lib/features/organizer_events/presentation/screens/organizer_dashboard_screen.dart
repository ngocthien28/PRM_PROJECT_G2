// CampusHub skeleton • lib/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../events/data/models/event_model.dart';
import '../../../../shared/enums/event_status.dart';
import '../viewmodels/organizer_events_view_model.dart';

/// Minimal organizer entry point until the full dashboard is implemented.
class OrganizerDashboardScreen extends ConsumerWidget {
  const OrganizerDashboardScreen({
    super.key,
    required this.onCreateEvent,
  });

  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(organizerEventsProvider);
    final eventCount = events.asData?.value
            .where((event) => event.status != EventStatus.cancelled)
            .length ??
        0;
    return Scaffold(
      appBar: AppBar(title: const Text('CampusHub Organizer')),
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
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Event management', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Create and manage campus experiences for your community.'),
                const SizedBox(height: 20),
                FilledButton.icon(key: const Key('createEventAction'), onPressed: onCreateEvent, icon: const Icon(Icons.add), label: const Text('Create Event')),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatCard(icon: Icons.event_available_outlined, label: 'My events', value: events.isLoading ? '—' : '$eventCount'),
            const SizedBox(height: 24),
            Text('My events', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            events.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (_, _) => const _EmptyState(message: 'Unable to load your events right now.'),
              data: (items) {
                final activeItems = items
                    .where((event) => event.status != EventStatus.cancelled)
                    .toList();
                return activeItems.isEmpty
                  ? const _EmptyState(message: 'No events yet. Create your first event to get started.')
                  : Column(
                      children: activeItems.map(
                            (event) => Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.event_outlined),
                                ),
                                title: Text(event.title),
                                subtitle: Text(event.locationName),
                                trailing: PopupMenuButton<_EventAction>(
                                  tooltip: 'Event actions',
                                  onSelected: (action) {
                                    _confirmCancel(context, ref, event);
                                  },
                                  itemBuilder: (_) => const [
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
        content: Text('“${event.title}” will be cancelled and hidden from students.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted.')),
        );
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

enum _EventAction { delete }

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(label), trailing: Text(value, style: Theme.of(context).textTheme.headlineSmall)));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [const Icon(Icons.event_note_outlined, size: 36), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center)])));
}

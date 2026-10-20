// CampusHub skeleton • lib/features/organizer_events/presentation/screens/manage_events_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/widgets/event_format.dart';
import '../../../events/presentation/widgets/event_poster.dart';
import '../viewmodels/organizer_events_view_model.dart';

class ManageEventsScreen extends ConsumerStatefulWidget {
  const ManageEventsScreen({super.key});

  @override
  ConsumerState<ManageEventsScreen> createState() => _ManageEventsScreenState();
}

class _ManageEventsScreenState extends ConsumerState<ManageEventsScreen> {
  String _query = '';
  EventStatus? _status;

  Future<void> _refresh() async {
    ref.invalidate(organizerEventsProvider);
    await ref.read(organizerEventsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(organizerEventsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Managed Events'),
        actions: [
          IconButton(
            key: const Key('managedEventsRefreshButton'),
            tooltip: 'Refresh events',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('managedEventsCreateButton'),
        onPressed: () => context.go(RouteNames.organizerCreateEvent),
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(error: error, onRetry: _refresh),
        data: (items) => _EventsBody(
          events: _filter(items),
          query: _query,
          status: _status,
          onQueryChanged: (value) => setState(() => _query = value),
          onStatusChanged: (value) => setState(() => _status = value),
          onRefresh: _refresh,
          onEdit: (event) => context.go(RouteNames.organizerEditEvent(event.id), extra: event),
          onCancel: _cancel,
          onOpen: (event) => context.push(RouteNames.eventDetail(event.id)),
          onCreate: () => context.go(RouteNames.organizerCreateEvent),
        ),
      ),
    );
  }

  List<EventModel> _filter(List<EventModel> events) {
    final query = _query.trim().toLowerCase();
    return events.where((event) =>
      (_status == null || event.status == _status) &&
      (query.isEmpty || event.title.toLowerCase().contains(query)),
    ).toList();
  }

  Future<void> _cancel(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel event?'),
        content: Text('“${event.title}” will no longer be available to students.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep event')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Cancel event')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(organizerEventActionsProvider).cancelEvent(event.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event cancelled.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to cancel this event.')));
    }
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody({required this.events, required this.query, required this.status, required this.onQueryChanged, required this.onStatusChanged, required this.onRefresh, required this.onEdit, required this.onCancel, required this.onOpen, required this.onCreate});
  final List<EventModel> events;
  final String query;
  final EventStatus? status;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<EventStatus?> onStatusChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<EventModel> onEdit;
  final ValueChanged<EventModel> onCancel;
  final ValueChanged<EventModel> onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Manage your events and track their status.', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 20),
              TextField(key: const Key('managedEventsSearchField'), onChanged: onQueryChanged, decoration: const InputDecoration(labelText: 'Search by title', prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('All'), selected: status == null, onSelected: (_) => onStatusChanged(null)),
                for (final value in EventStatus.values) ChoiceChip(label: Text(_statusLabel(value)), selected: status == value, onSelected: (_) => onStatusChanged(value)),
              ]),
            ]),
          ),
        ),
        if (events.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _EmptyState(hasFilters: query.trim().isNotEmpty || status != null, onCreate: onCreate))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: constraints.crossAxisExtent >= 760 ? 480 : 620, mainAxisExtent: 334, mainAxisSpacing: 16, crossAxisSpacing: 16),
                delegate: SliverChildBuilderDelegate((context, index) => _ManagedEventCard(event: events[index], onEdit: () => onEdit(events[index]), onCancel: () => onCancel(events[index]), onOpen: () => onOpen(events[index])), childCount: events.length),
              ),
            ),
          ),
      ],
    ),
  );
}

class _ManagedEventCard extends StatelessWidget {
  const _ManagedEventCard({required this.event, required this.onEdit, required this.onCancel, required this.onOpen});
  final EventModel event;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(height: 112, child: EventPoster(url: event.posterUrl, category: event.category, height: 112)),
      Expanded(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)), const SizedBox(width: 8), _StatusChip(status: event.status)]),
            const SizedBox(height: 6), Text(event.category, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 10), _InfoLine(icon: Icons.schedule_outlined, text: eventDateTime(context, event.startAt)),
            const SizedBox(height: 5), _InfoLine(icon: Icons.place_outlined, text: event.locationName),
            const SizedBox(height: 5), _InfoLine(icon: Icons.people_outline, text: '${event.registeredCount} / ${event.capacity} registered'),
          ])),
          PopupMenuButton<_ManagedAction>(
            tooltip: 'Manage event',
            onSelected: (action) => switch (action) { _ManagedAction.open => onOpen(), _ManagedAction.edit => onEdit(), _ManagedAction.cancel => onCancel() },
            itemBuilder: (_) => [
              if (event.status == EventStatus.published) const PopupMenuItem(value: _ManagedAction.open, child: Text('View details')),
              if (event.status != EventStatus.cancelled) const PopupMenuItem(value: _ManagedAction.edit, child: Text('Edit event')),
              if (event.status != EventStatus.cancelled) const PopupMenuItem(value: _ManagedAction.cancel, child: Text('Cancel event')),
            ],
          ),
        ]),
      )),
    ]),
  );
}

enum _ManagedAction { open, edit, cancel }

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(children: [Icon(icon, size: 16), const SizedBox(width: 6), Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis))]);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final EventStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) { EventStatus.published => Colors.green, EventStatus.draft => Colors.orange, EventStatus.cancelled => Colors.red, EventStatus.finished => Colors.blueGrey };
    return Chip(label: Text(_statusLabel(status)), visualDensity: VisualDensity.compact, side: BorderSide(color: color), labelStyle: TextStyle(color: color));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onCreate});
  final bool hasFilters;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.event_note_outlined, size: 48), const SizedBox(height: 12), Text(hasFilters ? 'No events match these filters.' : 'No managed events yet.', textAlign: TextAlign.center), if (!hasFilters) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create Event'))]])));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    final message = error is AppException
        ? (error as AppException).message
        : 'Unable to load your managed events.';
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 48), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))])));
  }
}

String _statusLabel(EventStatus status) => switch (status) {
  EventStatus.draft => 'Draft', EventStatus.published => 'Published', EventStatus.cancelled => 'Cancelled', EventStatus.finished => 'Finished',
};

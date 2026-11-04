// CampusHub • lib/features/organizer_events/presentation/screens/manage_events_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/widgets/event_format.dart';
import '../../../events/presentation/widgets/event_poster.dart';
import '../viewmodels/organizer_events_view_model.dart';
import '../widgets/cancel_event_dialog.dart';

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

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Chọn admin shell, fallback và isAdmin theo role hiện tại.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: Routes organizer/admin events.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod, go_router.
  @override
  Widget build(BuildContext context) {
    final events = ref.watch(organizerEventsProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    final fallback = user?.role == UserRole.admin
        ? RouteNames.admin
        : RouteNames.organizer;

    final content = events.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(error: error, onRetry: _refresh),
      data: (items) => _EventsBody(
        allItems: items,
        events: _filter(items),
        query: _query,
        status: _status,
        isAdmin: user?.role == UserRole.admin,
        onQueryChanged: (value) => setState(() => _query = value),
        onStatusChanged: (value) => setState(() => _status = value),
        onRefresh: _refresh,
        onEdit: (event) =>
            context.go(RouteNames.organizerEditEvent(event.id), extra: event),
        onCancel: _cancel,
        onOpen: (event) =>
            context.push(RouteNames.organizerEventDetail(event.id)),
        onCreate: () => context.go(RouteNames.organizerCreateEvent),
      ),
    );

    final createFab = FloatingActionButton.extended(
      key: const Key('managedEventsCreateButton'),
      onPressed: () => context.go(RouteNames.organizerCreateEvent),
      icon: const Icon(Icons.add),
      label: const Text('Create Event'),
    );

    if (user?.role == UserRole.admin) {
      return CampusScaffold(
        title: 'My Managed Events',
        section: CampusSection.events,
        role: 'admin',
        userName: user?.displayName ?? 'Administrator',
        actions: [
          IconButton(
            key: const Key('managedEventsRefreshButton'),
            tooltip: 'Refresh events',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        floatingActionButton: createFab,
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallbackLocation: fallback),
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
      floatingActionButton: createFab,
      body: content,
    );
  }

  List<EventModel> _filter(List<EventModel> events) {
    final query = _query.trim().toLowerCase();
    return events
        .where(
          (event) =>
              (_status == null || event.status == _status) &&
              (query.isEmpty || event.title.toLowerCase().contains(query)),
        )
        .toList();
  }

  Future<void> _cancel(EventModel event) async {
    final cancelled = await showCancelEventDialog(context, event);
    if (cancelled && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event cancelled.')));
    }
  }
}

class _EventsBody extends StatelessWidget {
  const _EventsBody({
    required this.allItems,
    required this.events,
    required this.query,
    required this.status,
    required this.isAdmin,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.onEdit,
    required this.onCancel,
    required this.onOpen,
    required this.onCreate,
  });

  final List<EventModel> allItems;
  final List<EventModel> events;
  final String query;
  final EventStatus? status;
  final bool isAdmin;
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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin
                      ? 'Review, update, or cancel events across the campus workspace.'
                      : 'Manage your events and track their status.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (allItems.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _OverviewMetricsBar(events: allItems),
                ],
                const SizedBox(height: 20),
                TextField(
                  key: const Key('managedEventsSearchField'),
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    labelText: 'Search by title',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => onQueryChanged(''),
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: status == null,
                      onSelected: (_) => onStatusChanged(null),
                    ),
                    for (final value in EventStatus.values)
                      ChoiceChip(
                        label: Text(_statusLabel(value)),
                        selected: status == value,
                        onSelected: (_) => onStatusChanged(value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (events.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(
              hasFilters: query.trim().isNotEmpty || status != null,
              onCreate: onCreate,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) => SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: constraints.crossAxisExtent >= 760
                      ? 480
                      : 620,
                  mainAxisExtent: 360,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ManagedEventCard(
                    event: events[index],
                    isAdmin: isAdmin,
                    onEdit: () => onEdit(events[index]),
                    onCancel: () => onCancel(events[index]),
                    onOpen: () => onOpen(events[index]),
                    onParticipants: () => context.push(
                      RouteNames.organizerEventParticipants(events[index].id),
                    ),
                  ),
                  childCount: events.length,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _OverviewMetricsBar extends StatelessWidget {
  const _OverviewMetricsBar({required this.events});
  final List<EventModel> events;

  @override
  Widget build(BuildContext context) {
    final total = events.length;
    final published = events
        .where((e) => e.status == EventStatus.published)
        .length;
    final cancelled = events
        .where((e) => e.status == EventStatus.cancelled)
        .length;
    final totalRegistrations = events.fold<int>(
      0,
      (sum, e) => sum + e.registeredCount,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final itemWidth = wide
            ? (constraints.maxWidth - 36) / 4
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: itemWidth,
              child: _MetricItem(
                label: 'Total events',
                value: '$total',
                icon: Icons.event_note,
                color: CampusColors.teal,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _MetricItem(
                label: 'Active events',
                value: '$published',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _MetricItem(
                label: 'Cancelled events',
                value: '$cancelled',
                icon: Icons.cancel_outlined,
                color: Colors.red,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _MetricItem(
                label: 'Attendees',
                value: '$totalRegistrations',
                icon: Icons.people_outline,
                color: Colors.indigo,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: CampusColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ManagedEventCard extends StatelessWidget {
  const _ManagedEventCard({
    required this.event,
    required this.isAdmin,
    required this.onEdit,
    required this.onCancel,
    required this.onOpen,
    this.onParticipants,
  });

  final EventModel event;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final VoidCallback? onParticipants;

  @override
  Widget build(BuildContext context) {
    final isCancelled = event.status == EventStatus.cancelled;
    final capacityFraction = event.capacity > 0
        ? (event.registeredCount / event.capacity).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isCancelled
              ? Colors.red.withValues(alpha: 0.3)
              : CampusColors.line,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 112,
              child: EventPoster(
                url: event.posterUrl,
                category: event.category,
                height: 112,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(status: event.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            event.category,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: CampusColors.teal),
                          ),
                          const SizedBox(height: 8),
                          _InfoLine(
                            icon: Icons.schedule_outlined,
                            text: eventDateTime(context, event.startAt),
                          ),
                          const SizedBox(height: 4),
                          _InfoLine(
                            icon: Icons.place_outlined,
                            text: event.locationName,
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () {
                              if (onParticipants != null) {
                                onParticipants!();
                              } else {
                                context.push(
                                  RouteNames.organizerEventParticipants(
                                    event.id,
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: _InfoLine(
                              icon: Icons.people_outline,
                              text:
                                  '${event.registeredCount} / ${event.capacity} registered',
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: capacityFraction,
                              minHeight: 5,
                              color: isCancelled
                                  ? Colors.grey
                                  : capacityFraction >= 1.0
                                  ? Colors.red
                                  : CampusColors.teal,
                              backgroundColor: CampusColors.canvas,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 13,
                                color: CampusColors.muted.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Organizer: ${event.organizerId}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
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
                    PopupMenuButton<_ManagedAction>(
                      tooltip: 'Manage event',
                      onSelected: (action) => switch (action) {
                        _ManagedAction.open => onOpen(),
                        _ManagedAction.scan => context.push(
                          RouteNames.organizerEventScan(event.id),
                          extra: event.title,
                        ),
                        _ManagedAction.edit => onEdit(),
                        _ManagedAction.cancel => onCancel(),
                        _ManagedAction.participants =>
                          onParticipants != null
                              ? onParticipants!()
                              : context.push(
                                  RouteNames.organizerEventParticipants(
                                    event.id,
                                  ),
                                ),
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: _ManagedAction.open,
                          child: Text('View details'),
                        ),
                        const PopupMenuItem(
                          value: _ManagedAction.participants,
                          child: Text('View participants'),
                        ),
                        if (event.status != EventStatus.cancelled)
                          const PopupMenuItem(
                            value: _ManagedAction.scan,
                            child: Text('Quét QR Check-in'),
                          ),
                        if (event.status != EventStatus.cancelled)
                          const PopupMenuItem(
                            value: _ManagedAction.edit,
                            child: Text('Edit event'),
                          ),
                        if (event.status != EventStatus.cancelled)
                          const PopupMenuItem(
                            value: _ManagedAction.cancel,
                            child: Text('Cancel Event'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ManagedAction { open, scan, edit, cancel, participants }

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 15, color: CampusColors.muted),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    ],
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final EventStatus status;
  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      EventStatus.published => (Colors.green, Icons.check_circle_outline),
      EventStatus.draft => (Colors.orange, Icons.edit_note),
      EventStatus.cancelled => (Colors.red, Icons.cancel_outlined),
      EventStatus.finished => (Colors.blueGrey, Icons.done_all),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters, required this.onCreate});
  final bool hasFilters;
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_note_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            hasFilters
                ? 'No events match these filters.'
                : 'No managed events yet.',
            textAlign: TextAlign.center,
          ),
          if (!hasFilters) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
            ),
          ],
        ],
      ),
    ),
  );
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(EventStatus status) => switch (status) {
  EventStatus.draft => 'Draft',
  EventStatus.published => 'Published',
  EventStatus.cancelled => 'Cancelled',
  EventStatus.finished => 'Finished',
};

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../../shared/widgets/role_navigation_actions.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/presentation/widgets/event_format.dart';
import '../../../events/presentation/widgets/event_poster.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../../data/models/organizer_dashboard_summary.dart';
import '../viewmodels/organizer_dashboard_view_model.dart';
import '../viewmodels/organizer_events_view_model.dart';

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

  Future<void> _refresh(WidgetRef ref) async {
    if (ref.read(organizerDashboardProvider).isLoading) return;
    ref.invalidate(organizerDashboardProvider);
    try {
      await ref.read(organizerDashboardProvider.future);
    } catch (_) {
      // The provider renders the failure; refresh must not throw into the UI.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(organizerDashboardProvider);
    final user = ref.watch(currentUserProvider).asData?.value;
    final canManage = user?.isActive == true && user?.role.canOrganize == true;
    return CampusScaffold(
      title: 'Organizer Dashboard',
      sidebarWidth: MediaQuery.textScalerOf(context).scale(232).clamp(232, 464),
      section: CampusSection.home,
      role: user?.role.name ?? 'organizer',
      userName: user?.displayName ?? 'Organizer',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      signOutKey: const Key('organizerSignOutButton'),
      actions: [
        if (MediaQuery.sizeOf(context).width >= 600)
          const RoleNavigationActions(),
        IconButton(
          key: const Key('dashboardRefreshButton'),
          tooltip: 'Refresh dashboard',
          onPressed: dashboard.isLoading ? null : () => _refresh(ref),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CampusPage(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CampusColors.ink,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR ORGANIZER WORKSPACE',
                    style: TextStyle(
                      color: CampusColors.gold,
                      fontSize: 10,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome, ${user?.displayName ?? 'Organizer'}',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Manage your events and monitor participation.',
                    style: TextStyle(color: Color(0xFFC2D6CC)),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        key: const Key('createEventAction'),
                        onPressed: canManage ? onCreateEvent : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: CampusColors.gold,
                          foregroundColor: CampusColors.ink,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Create Event'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('manageEventsAction'),
                        onPressed: canManage ? onManageEvents : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFF8EB7A0)),
                        ),
                        icon: const Icon(Icons.list_alt_outlined),
                        label: const Text('View all managed events'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            dashboard.when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              skipError: false,
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('dashboardLoading'),
                  ),
                ),
              ),
              error: (error, _) => CampusEmptyState(
                key: const Key('dashboardError'),
                icon: Icons.cloud_off_outlined,
                title: 'Unable to load dashboard',
                message: error is AppException
                    ? error.message
                    : 'We could not load your event summary. Please try again.',
                action: FilledButton.icon(
                  key: const Key('dashboardRetryButton'),
                  onPressed: () => _refresh(ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ),
              data: (summary) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionHeading(
                    title: 'Overview',
                    subtitle:
                        'Your events across all statuses. Participation totals are event registrations.',
                  ),
                  const SizedBox(height: 16),
                  _DashboardStats(summary: summary),
                  const SizedBox(height: 28),
                  if (summary.totalEvents == 0)
                    const CampusEmptyState(
                      key: Key('dashboardEmpty'),
                      icon: Icons.event_note_outlined,
                      title: 'No events yet',
                      message: 'Create your first event to get started.',
                    )
                  else ...[
                    SectionHeading(
                      title: 'Upcoming events',
                      subtitle:
                          '${summary.upcomingCount} upcoming · ${summary.ongoingCount} happening now · ${summary.pastCount} past',
                    ),
                    const SizedBox(height: 16),
                    if (summary.upcomingEvents.isEmpty)
                      const CampusEmptyState(
                        key: Key('dashboardNoUpcoming'),
                        icon: Icons.event_available_outlined,
                        title: 'No upcoming events',
                        message:
                            'Your past, draft and cancelled events are available in My Managed Events.',
                      )
                    else
                      _eventCards(
                        context,
                        ref,
                        summary.upcomingEvents,
                        summary.asOf,
                      ),
                    if (summary.recentEvents.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      const SectionHeading(
                        title: 'Recent & ongoing events',
                        subtitle:
                            'Continue managing attendance or review your event history.',
                      ),
                      const SizedBox(height: 16),
                      _eventCards(
                        context,
                        ref,
                        summary.recentEvents,
                        summary.asOf,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _eventCards(
    BuildContext context,
    WidgetRef ref,
    List<EventModel> events,
    DateTime asOf,
  ) {
    return Column(
      children: [
        for (final event in events) ...[
          _DashboardEventCard(
            event: event,
            asOf: asOf,
            onOpen: () async {
              await context.push(RouteNames.organizerEventDetail(event.id));
              if (context.mounted) await _refresh(ref);
            },
            onAction: (action) {
              switch (action) {
                case _EventAction.edit:
                  onEditEvent(event);
                case _EventAction.participants:
                  if (onViewParticipants != null) {
                    onViewParticipants!(event);
                  } else {
                    context.push(
                      RouteNames.organizerEventParticipants(event.id),
                    );
                  }
                case _EventAction.cancel:
                  _confirmCancel(context, ref, event);
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
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
        title: const Text('Cancel event?'),
        content: Text(
          '“${event.title}” will be cancelled and kept in your management history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep event'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel event'),
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
        ).showSnackBar(const SnackBar(content: Text('Event cancelled.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AppException
                  ? error.message
                  : 'Unable to cancel this event.',
            ),
          ),
        );
      }
    }
  }
}

class _DashboardStats extends StatelessWidget {
  const _DashboardStats({required this.summary});
  final OrganizerDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final stats = [
      (
        'totalEvents',
        'Total Events',
        summary.totalEvents,
        Icons.event_outlined,
      ),
      (
        'upcoming',
        'Upcoming Events',
        summary.upcomingCount,
        Icons.schedule_outlined,
      ),
      (
        'published',
        'Published Events',
        summary.publishedCount,
        Icons.publish_outlined,
      ),
      (
        'cancelled',
        'Cancelled Events',
        summary.cancelledCount,
        Icons.cancel_outlined,
      ),
      (
        'registrations',
        'Total Registrations',
        summary.totalRegistrations,
        Icons.people_outline,
      ),
      (
        'checkedIn',
        'Total Checked-in',
        summary.totalCheckedIn,
        Icons.fact_check_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 650
            ? 3
            : box.maxWidth >= 320
            ? 2
            : 1;
        return Column(
          children: [
            for (var index = 0; index < stats.length; index += columns) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (
                      var offset = 0;
                      offset < columns && index + offset < stats.length;
                      offset++
                    ) ...[
                      if (offset > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          key: Key('dashboardKpi-${stats[index + offset].$1}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  stats[index + offset].$4,
                                  color: CampusColors.teal,
                                ),
                                const SizedBox(height: 12),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${stats[index + offset].$3}',
                                    key: Key(
                                      'dashboardKpiValue-${stats[index + offset].$1}',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(stats[index + offset].$2),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (index + columns < stats.length) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

enum _EventAction { edit, participants, cancel }

class _DashboardEventCard extends StatelessWidget {
  const _DashboardEventCard({
    required this.event,
    required this.asOf,
    required this.onOpen,
    required this.onAction,
  });
  final EventModel event;
  final DateTime asOf;
  final VoidCallback onOpen;
  final ValueChanged<_EventAction> onAction;

  @override
  Widget build(BuildContext context) {
    final phase = OrganizerDashboardSummary.phaseOf(event, asOf);
    final phaseLabel = switch (phase) {
      DashboardEventPhase.upcoming => 'Upcoming',
      DashboardEventPhase.ongoing => 'Happening now',
      DashboardEventPhase.past => 'Past',
      DashboardEventPhase.draft => 'Draft',
      DashboardEventPhase.cancelled => 'Cancelled',
    };
    final statusLabel = switch (event.status) {
      EventStatus.published => 'Published',
      EventStatus.draft => 'Draft',
      EventStatus.cancelled => 'Cancelled',
      EventStatus.finished => 'Finished',
    };
    return Card(
      key: Key('dashboardEvent-${event.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EventPoster(
              url: event.posterUrl,
              category: event.category,
              height: 110,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      PopupMenuButton<_EventAction>(
                        key: Key('dashboardEventActions-${event.id}'),
                        tooltip: 'Event actions',
                        onSelected: onAction,
                        itemBuilder: (_) => [
                          if (event.status != EventStatus.cancelled)
                            const PopupMenuItem(
                              value: _EventAction.edit,
                              child: Text('Edit'),
                            ),
                          const PopupMenuItem(
                            value: _EventAction.participants,
                            child: Text('Participants'),
                          ),
                          if (event.status != EventStatus.cancelled)
                            const PopupMenuItem(
                              value: _EventAction.cancel,
                              child: Text('Cancel event'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(label: Text(statusLabel)),
                      if (phaseLabel != statusLabel) Text(phaseLabel),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(eventDateTime(context, event.startAt)),
                  const SizedBox(height: 6),
                  Text(event.locationName),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      Text(
                        '${event.registeredCount} / ${event.capacity} registered',
                      ),
                      Text('${event.checkedInCount} checked in'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: Key('dashboardDetails-${event.id}'),
                    onPressed: onOpen,
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View details'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

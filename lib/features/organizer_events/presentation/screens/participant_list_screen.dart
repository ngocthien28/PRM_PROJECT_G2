// CampusHub • lib/features/organizer_events/presentation/screens/participant_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../../shared/enums/registration_status.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../events/presentation/widgets/event_format.dart';
import '../../../registration/data/models/registration_model.dart';
import '../viewmodels/participant_summary_view_model.dart';

typedef ParticipantSummaryScreen = ParticipantListScreen;

/// Production organizer screen displaying event participant summary and list.
///
/// Handles loading, error, empty, and success states.
/// Receives [eventId] via route and fetches data through [participantSummaryProvider].
class ParticipantListScreen extends ConsumerWidget {
  const ParticipantListScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(participantSummaryProvider(eventId));

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(
          fallbackLocation: RouteNames.organizerManagedEvents,
        ),
        title: const Text('Event Participants'),
        actions: [
          IconButton(
            key: const Key('participantSummaryRefreshButton'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(participantSummaryProvider(eventId)),
          ),
        ],
      ),
      body: state.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(
          child: CircularProgressIndicator(
            key: Key('participantSummaryLoading'),
          ),
        ),
        error: (error, stack) {
          final failure = error is AppException
              ? error
              : mapError(error, stack);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      failure.message,
                      key: const Key('participantSummaryError'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          key: const Key('participantSummaryRetryButton'),
                          onPressed: () => ref.invalidate(
                            participantSummaryProvider(eventId),
                          ),
                          child: const Text('Retry'),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () =>
                              context.go(RouteNames.organizerManagedEvents),
                          child: const Text('Back to managed events'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        data: (summary) =>
            _ParticipantSummaryContent(eventId: eventId, summary: summary),
      ),
    );
  }
}

class _ParticipantSummaryContent extends StatelessWidget {
  const _ParticipantSummaryContent({
    required this.eventId,
    required this.summary,
  });

  final String eventId;
  final ParticipantSummaryState summary;

  @override
  Widget build(BuildContext context) {
    final event = summary.event;
    final rateText = summary.registeredCount > 0
        ? '${summary.attendanceRate.toStringAsFixed(1)}%'
        : '0%';

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Event Header Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: CampusColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                event.title,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _EventStatusBadge(status: event.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              size: 16,
                              color: CampusColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                eventDateTime(context, event.startAt),
                                style: const TextStyle(
                                  color: CampusColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.place_outlined,
                              size: 16,
                              color: CampusColors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                event.locationName,
                                style: const TextStyle(
                                  color: CampusColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Event ID: ${event.id}',
                          style: TextStyle(
                            fontSize: 11,
                            color: CampusColors.muted.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Statistics Cards
                Text(
                  'Participant Statistics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth.clamp(0, 900) - 64) / 3
                          : (constraints.maxWidth - 52) / 2,
                      child: _StatCard(
                        icon: Icons.people_alt_outlined,
                        color: CampusColors.teal,
                        label: 'Total Registered',
                        value: '${summary.registeredCount} / ${event.capacity}',
                        valueKey: const Key('statTotalRegistered'),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth.clamp(0, 900) - 64) / 3
                          : (constraints.maxWidth - 52) / 2,
                      child: _StatCard(
                        icon: Icons.how_to_reg_outlined,
                        color: Colors.green.shade700,
                        label: 'Total Checked-in',
                        value: '${summary.checkedInCount}',
                        valueKey: const Key('statTotalCheckedIn'),
                      ),
                    ),
                    SizedBox(
                      width: wide
                          ? (constraints.maxWidth.clamp(0, 900) - 64) / 3
                          : constraints.maxWidth - 40,
                      child: _StatCard(
                        icon: Icons.pie_chart_outline,
                        color: CampusColors.ink,
                        label: 'Attendance Rate',
                        value: rateText,
                        valueKey: const Key('statAttendanceRate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Participant List Header
                Text(
                  'Participant List (${summary.participants.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Empty / List View
                if (summary.participants.isEmpty)
                  Card(
                    elevation: 0,
                    color: CampusColors.canvas,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: CampusColors.line),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 36,
                        horizontal: 20,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 40,
                            color: CampusColors.muted,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No participants have registered for this event yet.',
                            key: Key('emptyParticipantsMessage'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: CampusColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...summary.participants.map(
                    (participant) => _ParticipantTile(participant: participant),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CampusColors.line),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  key: valueKey,
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
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant});

  final RegistrationModel participant;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: CampusColors.line),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: CampusColors.mint,
          child: const Icon(Icons.person, color: CampusColors.teal),
        ),
        title: Text(
          'User: ${participant.userId}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Registered: ${eventDateTime(context, participant.registeredAt)}',
              style: const TextStyle(fontSize: 12, color: CampusColors.muted),
            ),
            if (participant.checkedInAt != null) ...[
              const SizedBox(height: 2),
              Text(
                'Checked in: ${eventDateTime(context, participant.checkedInAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        trailing: _RegistrationStatusChip(status: participant.status),
      ),
    );
  }
}

class _EventStatusBadge extends StatelessWidget {
  const _EventStatusBadge({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      EventStatus.draft => (
        Colors.amber.shade50,
        Colors.amber.shade900,
        'Draft',
      ),
      EventStatus.published => (
        CampusColors.mint,
        CampusColors.teal,
        'Published',
      ),
      EventStatus.cancelled => (
        Colors.red.shade50,
        Colors.red.shade800,
        'Cancelled',
      ),
      EventStatus.finished => (
        Colors.blueGrey.shade50,
        Colors.blueGrey.shade800,
        'Finished',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _RegistrationStatusChip extends StatelessWidget {
  const _RegistrationStatusChip({required this.status});

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      RegistrationStatus.registered => (CampusColors.mint, CampusColors.teal),
      RegistrationStatus.checkedIn => (
        Colors.green.shade50,
        Colors.green.shade800,
      ),
      RegistrationStatus.cancelled => (Colors.red.shade50, Colors.red.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

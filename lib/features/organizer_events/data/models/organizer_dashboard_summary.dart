import '../../../../core/errors/app_exception.dart';
import '../../../../shared/enums/event_status.dart';
import '../../../events/data/models/event_model.dart';

enum DashboardEventPhase { upcoming, ongoing, past, draft, cancelled }

/// Read-only totals for one owner, independent of the managed-list page size.
class OrganizerDashboardSummary {
  OrganizerDashboardSummary._(OrganizerDashboardAccumulator source)
    : organizerId = source.organizerId,
      asOf = source.asOf,
      totalEvents = source.totalEvents,
      upcomingCount = source.upcomingCount,
      publishedCount = source.publishedCount,
      cancelledCount = source.cancelledCount,
      ongoingCount = source.ongoingCount,
      pastCount = source.pastCount,
      totalRegistrations = source.totalRegistrations,
      totalCheckedIn = source.totalCheckedIn,
      upcomingEvents = List.unmodifiable(source._upcoming),
      recentEvents = List.unmodifiable(source._recent);

  factory OrganizerDashboardSummary.fromEvents(
    Iterable<EventModel> events, {
    required String organizerId,
    required DateTime asOf,
  }) {
    final accumulator = OrganizerDashboardAccumulator(
      organizerId: organizerId,
      asOf: asOf,
    );
    for (final event in events) {
      accumulator.add(event);
    }
    return accumulator.finish();
  }

  final String organizerId;
  final DateTime asOf;
  final int totalEvents, upcomingCount, publishedCount, cancelledCount;
  final int ongoingCount, pastCount, totalRegistrations, totalCheckedIn;
  final List<EventModel> upcomingEvents, recentEvents;

  static DashboardEventPhase phaseOf(EventModel event, DateTime asOf) {
    if (event.status == EventStatus.cancelled) {
      return DashboardEventPhase.cancelled;
    }
    if (event.status == EventStatus.draft) return DashboardEventPhase.draft;
    if (event.status == EventStatus.finished || !event.endAt.isAfter(asOf)) {
      return DashboardEventPhase.past;
    }
    return event.startAt.isAfter(asOf)
        ? DashboardEventPhase.upcoming
        : DashboardEventPhase.ongoing;
  }
}

/// Aggregates bounded repository pages, retaining only small event previews.
/// Duplicate IDs cannot inflate totals if an event moves between pages.
class OrganizerDashboardAccumulator {
  OrganizerDashboardAccumulator({
    required this.organizerId,
    required DateTime asOf,
  }) : asOf = asOf.toUtc();

  static const upcomingLimit = 5;
  static const recentLimit = 3;
  final String organizerId;
  final DateTime asOf;
  final _seenIds = <String>{};
  final _upcoming = <EventModel>[];
  final _recent = <EventModel>[];
  int totalEvents = 0,
      upcomingCount = 0,
      publishedCount = 0,
      cancelledCount = 0;
  int ongoingCount = 0, pastCount = 0;
  int totalRegistrations = 0, totalCheckedIn = 0;

  void add(EventModel event) {
    if (event.organizerId != organizerId) {
      throw const AppException(
        'The dashboard returned events for another organizer. Please retry.',
        code: 'dashboard-owner-mismatch',
      );
    }
    if (!_seenIds.add(event.id)) return;
    if (event.registeredCount < 0 ||
        event.checkedInCount < 0 ||
        event.registeredCount > event.capacity ||
        event.checkedInCount > event.registeredCount) {
      throw const AppException(
        'Participation counters are inconsistent. Contact the event administrator.',
        code: 'dashboard-invalid-counters',
      );
    }
    totalEvents++;
    totalRegistrations += event.registeredCount;
    totalCheckedIn += event.checkedInCount;
    if (event.status == EventStatus.published) publishedCount++;
    if (event.status == EventStatus.cancelled) cancelledCount++;
    final phase = OrganizerDashboardSummary.phaseOf(event, asOf);
    switch (phase) {
      case DashboardEventPhase.upcoming:
        upcomingCount++;
        _upcoming.add(event);
        _upcoming.sort(_compareStart);
        if (_upcoming.length > upcomingLimit) _upcoming.removeLast();
      case DashboardEventPhase.ongoing:
        ongoingCount++;
      case DashboardEventPhase.past:
        pastCount++;
      case DashboardEventPhase.draft:
      case DashboardEventPhase.cancelled:
        break;
    }
    if (!event.startAt.isAfter(asOf)) {
      _recent.add(event);
      _recent.sort((a, b) => _compareStart(b, a));
      if (_recent.length > recentLimit) _recent.removeLast();
    }
  }

  static int _compareStart(EventModel a, EventModel b) {
    final order = a.startAt.compareTo(b.startAt);
    return order != 0 ? order : a.id.compareTo(b.id);
  }

  OrganizerDashboardSummary finish() => OrganizerDashboardSummary._(this);
}

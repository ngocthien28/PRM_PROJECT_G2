import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/organizer_events/data/models/organizer_dashboard_summary.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/event_fakes.dart';

void main() {
  final now = DateTime.utc(2030, 5, 1, 10);
  OrganizerDashboardSummary summarize(Iterable<EventModel> events) =>
      OrganizerDashboardSummary.fromEvents(
        events,
        organizerId: 'organizer-1',
        asOf: now,
      );

  test('empty owner has six zero KPIs and no previews', () {
    final summary = summarize([]);
    expect([
      summary.totalEvents,
      summary.upcomingCount,
      summary.publishedCount,
      summary.cancelledCount,
      summary.totalRegistrations,
      summary.totalCheckedIn,
    ], everyElement(0));
    expect(summary.upcomingEvents, isEmpty);
    expect(summary.recentEvents, isEmpty);
  });

  test(
    'a published future event contributes to total, upcoming and published',
    () {
      final summary = summarize([
        testEvent(
          startAt: now.add(const Duration(days: 1)),
          registeredCount: 7,
          checkedInCount: 2,
        ),
      ]);
      expect(summary.totalEvents, 1);
      expect(summary.upcomingCount, 1);
      expect(summary.publishedCount, 1);
      expect(summary.totalRegistrations, 7);
      expect(summary.totalCheckedIn, 2);
    },
  );

  for (final status in [
    EventStatus.cancelled,
    EventStatus.finished,
    EventStatus.draft,
  ]) {
    test('$status stays in totals but is never upcoming', () {
      final summary = summarize([
        testEvent(status: status, startAt: now.add(const Duration(days: 1))),
      ]);
      expect(summary.totalEvents, 1);
      expect(summary.upcomingCount, 0);
      expect(summary.publishedCount, 0);
      expect(summary.cancelledCount, status == EventStatus.cancelled ? 1 : 0);
    });
  }

  test('past published, ongoing and future published have distinct phases', () {
    final summary = summarize([
      testEvent(id: 'past', startAt: now.subtract(const Duration(hours: 4))),
      testEvent(id: 'ongoing', startAt: now.subtract(const Duration(hours: 1))),
      testEvent(id: 'future', startAt: now.add(const Duration(minutes: 1))),
    ]);
    expect(summary.publishedCount, 3);
    expect(summary.upcomingCount, 1);
    expect(summary.ongoingCount, 1);
    expect(summary.pastCount, 1);
    expect(summary.upcomingEvents.single.id, 'future');
  });

  test('start equals now is ongoing; end equals now is past', () {
    expect(
      OrganizerDashboardSummary.phaseOf(testEvent(startAt: now), now),
      DashboardEventPhase.ongoing,
    );
    expect(
      OrganizerDashboardSummary.phaseOf(
        testEvent(startAt: now.subtract(const Duration(hours: 2))),
        now,
      ),
      DashboardEventPhase.past,
    );
    final sameInstantLocal = now.toLocal();
    expect(
      OrganizerDashboardSummary.phaseOf(
        testEvent(startAt: sameInstantLocal),
        now,
      ),
      DashboardEventPhase.ongoing,
    );
  });

  test(
    'mixed statuses sum event registrations, including cancelled event history',
    () {
      final summary = summarize([
        testEvent(id: 'a', registeredCount: 9, checkedInCount: 4),
        testEvent(
          id: 'b',
          status: EventStatus.cancelled,
          registeredCount: 2,
          checkedInCount: 0,
        ),
        testEvent(
          id: 'c',
          status: EventStatus.finished,
          registeredCount: 6,
          checkedInCount: 6,
        ),
        testEvent(id: 'd', status: EventStatus.draft, registeredCount: 0),
      ]);
      expect(summary.totalEvents, 4);
      expect(summary.publishedCount, 1);
      expect(summary.cancelledCount, 1);
      expect(summary.totalRegistrations, 17);
      expect(summary.totalCheckedIn, 10);
    },
  );

  test(
    'zero registrations never need division or a fabricated attendance percentage',
    () {
      final summary = summarize([
        testEvent(registeredCount: 0, checkedInCount: 0),
      ]);
      expect(summary.totalRegistrations, 0);
      expect(summary.totalCheckedIn, 0);
    },
  );

  test(
    'foreign organizer data fails closed instead of contributing to totals',
    () {
      expect(
        () => summarize([
          testEvent(),
          testEvent(id: 'foreign', organizerId: 'other'),
        ]),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'dashboard-owner-mismatch',
          ),
        ),
      );
    },
  );

  test('duplicate document IDs never inflate KPIs', () {
    final event = testEvent();
    final summary = summarize([event, event]);
    expect(summary.totalEvents, 1);
    expect(summary.totalRegistrations, event.registeredCount);
  });

  test(
    'more than one page contributes while preview lists stay bounded and sorted',
    () {
      final summary = summarize(
        List.generate(
          225,
          (i) => testEvent(
            id: 'event-$i',
            startAt: now.add(Duration(days: 225 - i)),
            registeredCount: 1,
          ),
        ),
      );
      expect(summary.totalEvents, 225);
      expect(summary.totalRegistrations, 225);
      expect(summary.upcomingEvents.length, 5);
      expect(summary.upcomingEvents.first.id, 'event-224');
      expect(summary.upcomingEvents.last.id, 'event-220');
    },
  );

  test(
    'recent events include finished/cancelled history and keep only the latest three',
    () {
      final summary = summarize(
        List.generate(
          8,
          (i) => testEvent(
            id: 'past-$i',
            startAt: now.subtract(Duration(days: i + 1)),
            status: i.isEven ? EventStatus.cancelled : EventStatus.finished,
          ),
        ),
      );
      expect(summary.totalEvents, 8);
      expect(summary.recentEvents.map((e) => e.id), [
        'past-0',
        'past-1',
        'past-2',
      ]);
      expect(() => summary.recentEvents.clear(), throwsUnsupportedError);
    },
  );

  test('inconsistent counters are reported, never clamped or repaired', () {
    for (final event in [
      testEvent(registeredCount: 2, checkedInCount: 3),
      testEvent(registeredCount: -1),
      testEvent(registeredCount: 101, capacity: 100),
    ]) {
      expect(
        () => summarize([event]),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'dashboard-invalid-counters',
          ),
        ),
      );
    }
  });
}

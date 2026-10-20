import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/data/models/organizer_dashboard_summary.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_dashboard_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

class _DelayedDashboards extends FakeEvents {
  final requests = <String, Completer<OrganizerDashboardSummary>>{};
  @override
  Future<OrganizerDashboardSummary> getOrganizerDashboard({
    required AppUser actor,
    required DateTime asOf,
  }) {
    dashboardReads++;
    return (requests[actor.uid] ??= Completer()).future;
  }
}

void main() {
  final now = DateTime.utc(2030, 5, 1);
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late FakeEvents repository;
  late StreamController<AppUser?> profiles;
  late ProviderContainer container;
  setUp(() {
    repository = FakeEvents([testEvent()]);
    profiles = StreamController<AppUser?>.broadcast();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => profiles.stream),
        eventRepositoryProvider.overrideWithValue(repository),
        organizerDashboardClockProvider.overrideWithValue(() => now),
      ],
    );
    container.listen(organizerDashboardProvider, (_, _) {});
  });
  tearDown(() async {
    container.dispose();
    await profiles.close();
  });

  test(
    'loading waits for auth, then loads once with no repeated reads on rebuild',
    () async {
      expect(container.read(organizerDashboardProvider).isLoading, isTrue);
      expect(repository.dashboardReads, 0);
      profiles.add(owner);
      final summary = await container.read(organizerDashboardProvider.future);
      expect(summary.totalEvents, 1);
      for (var i = 0; i < 20; i++) {
        container.read(organizerDashboardProvider);
      }
      expect(repository.dashboardReads, 1);
    },
  );

  test(
    'empty is success; failures stay errors until an explicit retry',
    () async {
      repository.failure = const AppException(
        'No connection.',
        code: 'unavailable',
      );
      profiles.add(owner);
      await expectLater(
        container.read(organizerDashboardProvider.future),
        throwsA(isA<AppException>()),
      );
      expect(container.read(organizerDashboardProvider).hasError, isTrue);
      expect(repository.dashboardReads, 1);
      repository.failure = null;
      repository.events = [];
      container.invalidate(organizerDashboardProvider);
      expect(
        (await container.read(organizerDashboardProvider.future)).totalEvents,
        0,
      );
      expect(repository.dashboardReads, 2);
    },
  );

  test('refresh reads changed registration/check-in counters', () async {
    profiles.add(owner);
    await container.read(organizerDashboardProvider.future);
    repository.events = [testEvent(registeredCount: 48, checkedInCount: 25)];
    container.invalidate(organizerDashboardProvider);
    final summary = await container.read(organizerDashboardProvider.future);
    expect(summary.totalRegistrations, 48);
    expect(summary.totalCheckedIn, 25);
    expect(repository.dashboardReads, 2);
  });

  test(
    'create/edit/cancel actions invalidate dashboard while preserving totals/history',
    () async {
      profiles.add(owner);
      await container.read(organizerDashboardProvider.future);
      final actions = container.read(organizerEventActionsProvider);
      final input = EventFormInput(
        title: 'New campus workshop',
        description: 'A hands-on campus workshop with practical exercises.',
        category: 'technology',
        locationName: 'Hall B',
        startAt: now.add(const Duration(days: 5)),
        endAt: now.add(const Duration(days: 5, hours: 2)),
        capacity: 30,
      );
      await actions.createEvent(input);
      expect(
        (await container.read(organizerDashboardProvider.future)).totalEvents,
        2,
      );
      final created = repository.events.last;
      await actions.updateEvent(
        created.id,
        EventFormInput(
          title: 'Updated workshop',
          description: input.description,
          category: input.category,
          locationName: 'New location',
          startAt: now.subtract(const Duration(days: 1)),
          endAt: now.subtract(const Duration(hours: 22)),
          capacity: 30,
        ),
      );
      final edited = await container.read(organizerDashboardProvider.future);
      expect(edited.upcomingCount, 1);
      expect(edited.recentEvents.single.title, 'Updated workshop');
      expect(edited.recentEvents.single.locationName, 'New location');
      await actions.cancelEvent(created.id);
      final cancelled = await container.read(organizerDashboardProvider.future);
      expect(cancelled.totalEvents, 2);
      expect(cancelled.cancelledCount, 1);
    },
  );

  for (final user in <AppUser?>[
    null,
    testUser(),
    testUser(role: UserRole.organizer, status: 'disabled'),
  ]) {
    test(
      'invalid dashboard actor ${user?.role}/${user?.status} cannot call repository',
      () async {
        profiles.add(user);
        await expectLater(
          container.read(organizerDashboardProvider.future),
          throwsA(isA<AppException>()),
        );
        expect(repository.dashboardReads, 0);
      },
    );
  }

  test(
    'a late response for organizer A cannot overwrite organizer B after account switch',
    () async {
      container.dispose();
      final delayed = _DelayedDashboards();
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => profiles.stream),
          eventRepositoryProvider.overrideWithValue(delayed),
          organizerDashboardClockProvider.overrideWithValue(() => now),
        ],
      );
      container.listen(organizerDashboardProvider, (_, _) {});
      profiles.add(owner);
      await Future<void>.delayed(Duration.zero);
      expect(delayed.requests, contains(owner.uid));
      profiles.add(testUser(uid: 'organizer-b', role: UserRole.organizer));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(organizerDashboardProvider).isLoading, isTrue);
      await container.pump();
      await Future<void>.delayed(Duration.zero);
      expect(delayed.requests, contains('organizer-b'));
      delayed.requests['organizer-b']!.complete(
        OrganizerDashboardSummary.fromEvents(
          [testEvent(id: 'b-only', organizerId: 'organizer-b')],
          organizerId: 'organizer-b',
          asOf: now,
        ),
      );
      expect(
        (await container.read(organizerDashboardProvider.future)).organizerId,
        'organizer-b',
      );
      delayed.requests[owner.uid]!.complete(
        OrganizerDashboardSummary.fromEvents(
          <EventModel>[],
          organizerId: owner.uid,
          asOf: now,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container
            .read(organizerDashboardProvider)
            .requireValue
            .upcomingEvents
            .single
            .id,
        'b-only',
      );
    },
  );
}

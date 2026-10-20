import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_detail_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_dashboard_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import 'cancel_event_fakes.dart';

void main() {
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late CancelEventsFake repository;
  late OrganizerEventActions actions;
  late int refreshes;
  setUp(() {
    repository = CancelEventsFake();
    refreshes = 0;
    actions = OrganizerEventActions(
      repository: repository,
      currentActor: () => owner,
      refresh: () => refreshes++,
    );
  });

  test(
    'duplicate submissions share a request and refresh exactly once after acknowledgement',
    () async {
      final gate = Completer<void>();
      repository.cancelGate = gate.future;
      final first = actions.cancelEvent('event-1');
      final second = actions.cancelEvent('event-1');
      await Future<void>.delayed(Duration.zero);
      expect(repository.cancelRequests, 1);
      expect(refreshes, 0);
      gate.complete();
      await Future.wait([first, second]);
      expect(refreshes, 1);
      expect(repository.cancelledIds, ['event-1']);
    },
  );
  test(
    'failure resets the in-flight lock, does not refresh and allows retry',
    () async {
      repository.cancelFailure = const AppException(
        'Offline',
        code: 'unavailable',
      );
      await expectLater(
        actions.cancelEvent('event-1'),
        throwsA(isA<AppException>()),
      );
      expect(refreshes, 0);
      repository.cancelFailure = null;
      await actions.cancelEvent('event-1');
      expect(repository.cancelRequests, 2);
      expect(refreshes, 1);
    },
  );
  test(
    'bounded timeout allows retry without duplicating a still-pending request',
    () async {
      final gate = Completer<void>();
      repository.cancelGate = gate.future;
      actions = OrganizerEventActions(
        repository: repository,
        currentActor: () => owner,
        refresh: () => refreshes++,
        cancelTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        actions.cancelEvent('event-1'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'event-cancel-timeout',
          ),
        ),
      );
      final retry = actions.cancelEvent('event-1');
      await Future<void>.delayed(Duration.zero);
      expect(repository.cancelRequests, 1);
      expect(refreshes, 0);
      gate.complete();
      await retry;
      expect(refreshes, 1);
    },
  );
  test(
    'a missing or stalled auth session does not call the repository',
    () async {
      for (final session in [Future.value(null), Completer<Never>().future]) {
        actions = OrganizerEventActions(
          repository: repository,
          currentActor: () => session,
          refresh: () => refreshes++,
          cancelTimeout: const Duration(milliseconds: 20),
        );
        await expectLater(
          actions.cancelEvent('event-1'),
          throwsA(isA<AppException>()),
        );
      }
      expect(repository.cancelRequests, 0);
    },
  );
  test(
    'successful cancel invalidates management, dashboard, discovery and detail providers',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(owner)),
          authStateProvider.overrideWith((ref) => Stream.value(testIdentity)),
          eventRepositoryProvider.overrideWithValue(repository),
          organizerDashboardClockProvider.overrideWithValue(
            () => DateTime.utc(2030, 5, 1),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(organizerEventsProvider, (_, _) {});
      container.listen(organizerDashboardProvider, (_, _) {});
      container.listen(homeEventsProvider, (_, _) {});
      container.listen(eventListProvider, (_, _) {});
      container.listen(managedEventDetailProvider('event-1'), (_, _) {});
      await Future.wait([
        container.read(organizerEventsProvider.future),
        container.read(organizerDashboardProvider.future),
        container.read(homeEventsProvider.future),
        container.read(eventListProvider.future),
        container.read(managedEventDetailProvider('event-1').future),
      ]);
      await container
          .read(organizerEventActionsProvider)
          .cancelEvent('event-1');
      expect(
        (await container.read(organizerEventsProvider.future)).single.status,
        EventStatus.cancelled,
      );
      final summary = await container.read(organizerDashboardProvider.future);
      expect(summary.totalEvents, 1);
      expect(summary.cancelledCount, 1);
      expect(summary.upcomingCount, 0);
      expect(await container.read(homeEventsProvider.future), isEmpty);
      expect(await container.read(eventListProvider.future), isEmpty);
      expect(
        (await container.read(
          managedEventDetailProvider('event-1').future,
        )).status,
        EventStatus.cancelled,
      );
    },
  );
}

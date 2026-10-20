import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/theme/app_theme.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/screens/manage_events_screen.dart';
import 'package:campushub/features/organizer_events/presentation/screens/organizer_dashboard_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_dashboard_view_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import 'cancel_event_fakes.dart';

void main() {
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late CancelEventsFake repository;
  late ProviderContainer container;
  setUp(() {
    repository = CancelEventsFake();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(owner)),
        eventRepositoryProvider.overrideWithValue(repository),
        organizerDashboardClockProvider.overrideWithValue(
          () => DateTime.utc(2030, 5, 1),
        ),
        unreadNotificationCountProvider.overrideWithValue(0),
      ],
    );
  });
  tearDown(() => container.dispose());
  final dialog = find.byKey(const Key('cancelEventDialog'));
  final confirm = find.byKey(const Key('confirmCancelEventButton'));
  final keep = find.byKey(const Key('keepEventButton'));

  Future<void> mount(WidgetTester tester, bool dashboard) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: dashboard
              ? OrganizerDashboardScreen(
                  onCreateEvent: () {},
                  onManageEvents: () {},
                  onEditEvent: (_) {},
                )
              : const ManageEventsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, bool dashboard) async {
    final finder = dashboard
        ? find.byKey(const Key('dashboardEventActions-event-1'))
        : find.byTooltip('Manage event');
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester, bool dashboard) async {
    await mount(tester, dashboard);
    await menu(tester, dashboard);
    await tester.tap(find.text('Cancel Event'));
    await tester.pumpAndSettle();
  }

  for (final dashboard in [true, false]) {
    final screen = dashboard ? 'Dashboard' : 'Managed Events';
    for (final dismiss in ['Keep Event', 'Escape']) {
      testWidgets(
        '$screen: confirmation explains retention; $dismiss does not cancel',
        (tester) async {
          await open(tester, dashboard);
          expect(dialog, findsOneWidget);
          expect(find.text('Cancel Event'), findsNWidgets(2));
          expect(find.text('Delete Event'), findsNothing);
          expect(
            find.textContaining('existing registrations will be kept'),
            findsOneWidget,
          );
          if (dismiss == 'Keep Event') {
            await tester.tap(keep);
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(repository.cancelRequests, 0);
          expect(repository.events.single.status, EventStatus.published);
        },
      );
    }
    testWidgets(
      '$screen: double tap sends once; loading disables actions and Back; success refreshes',
      (tester) async {
        final gate = Completer<void>();
        repository.cancelGate = gate.future;
        await open(tester, dashboard);
        await tester.tap(confirm);
        await tester.tap(confirm);
        await tester.pump();
        expect(repository.cancelRequests, 1);
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        expect(tester.widget<TextButton>(keep).onPressed, isNull);
        expect(find.byKey(const Key('cancelEventLoading')), findsOneWidget);
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        expect(dialog, findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(dialog, findsOneWidget);
        expect(find.text('Event cancelled.'), findsNothing);
        gate.complete();
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(find.text('Event cancelled.'), findsOneWidget);
        expect(repository.cancelledIds, ['event-1']);
        expect(repository.events.single.status, EventStatus.cancelled);
        if (dashboard) {
          expect(
            tester
                .widget<Text>(
                  find.byKey(const Key('dashboardKpiValue-cancelled')),
                )
                .data,
            '1',
          );
          expect(
            tester
                .widget<Text>(
                  find.byKey(const Key('dashboardKpiValue-totalEvents')),
                )
                .data,
            '1',
          );
          expect(find.byKey(const Key('dashboardNoUpcoming')), findsOneWidget);
        } else {
          expect(find.text('Flutter Workshop'), findsOneWidget);
          expect(find.text('Cancelled'), findsWidgets);
          await menu(tester, dashboard);
          expect(find.text('Cancel Event'), findsNothing);
        }
        expect(tester.takeException(), isNull);
      },
    );
    for (final code in [
      'permission-denied',
      'unavailable',
      'event-not-found',
      'unexpected',
    ]) {
      testWidgets(
        '$screen: $code keeps dialog open, resets loading and retries safely',
        (tester) async {
          repository.cancelFailure = code == 'unexpected'
              ? StateError('native details')
              : AppException('Backend detail', code: code);
          await open(tester, dashboard);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(dialog, findsOneWidget);
          expect(find.byKey(const Key('cancelEventError')), findsOneWidget);
          expect(find.text('Event cancelled.'), findsNothing);
          expect(find.text('Backend detail'), findsNothing);
          expect(find.text('native details'), findsNothing);
          expect(find.byKey(const Key('cancelEventLoading')), findsNothing);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          expect(tester.widget<TextButton>(keep).onPressed, isNotNull);
          expect(find.text('Retry'), findsOneWidget);
          expect(find.text('Back'), findsOneWidget);
          expect(repository.events.single.status, EventStatus.published);
          repository.cancelFailure = null;
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(dialog, findsNothing);
          expect(repository.cancelRequests, 2);
          expect(find.text('Event cancelled.'), findsOneWidget);
        },
      );
    }
    testWidgets(
      '$screen: timeout unlocks dialog; retry shares the pending operation',
      (tester) async {
        final gate = Completer<void>();
        repository.cancelGate = gate.future;
        await open(tester, dashboard);
        await tester.tap(confirm);
        await tester.pump();
        await tester.pump(const Duration(seconds: 21));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cancelEventError')), findsOneWidget);
        expect(find.byKey(const Key('cancelEventLoading')), findsNothing);
        await tester.tap(confirm);
        await tester.pump();
        expect(repository.cancelRequests, 1);
        gate.complete();
        await tester.pumpAndSettle();
        expect(dialog, findsNothing);
        expect(find.text('Event cancelled.'), findsOneWidget);
      },
    );
    testWidgets('$screen: cancelled history never offers Cancel Event again', (
      tester,
    ) async {
      repository.events = [
        testEvent(
          status: EventStatus.cancelled,
          startAt: DateTime.utc(2030, 4),
        ),
      ];
      await mount(tester, dashboard);
      await menu(tester, dashboard);
      expect(find.text('Cancel Event'), findsNothing);
      expect(repository.cancelRequests, 0);
    });
  }
}

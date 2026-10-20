import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/presentation/screens/participant_list_screen.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/participant_summary_view_model.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/event_fakes.dart';
import '../registration/registration_fakes.dart';

void main() {
  Widget buildScreen({
    required String eventId,
    required Future<ParticipantSummaryState> Function() load,
  }) {
    return ProviderScope(
      overrides: [
        participantSummaryProvider(eventId).overrideWith((ref) => load()),
      ],
      child: MaterialApp(home: ParticipantListScreen(eventId: eventId)),
    );
  }

  group('ParticipantListScreen Widget Tests', () {
    testWidgets('renders loading indicator while loading', (tester) async {
      final completer = Completer<ParticipantSummaryState>();
      await tester.pumpWidget(
        buildScreen(eventId: 'event-1', load: () => completer.future),
      );

      expect(
        find.byKey(const Key('participantSummaryLoading')),
        findsOneWidget,
      );

      completer.complete(
        ParticipantSummaryState(
          event: testEvent(id: 'event-1'),
          participants: const [],
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('renders empty participants state with zero-safe rate', (
      tester,
    ) async {
      final event = testEvent(
        id: 'event-1',
        title: 'Campus Hackathon',
        capacity: 100,
        registeredCount: 0,
        checkedInCount: 0,
      );

      await tester.pumpWidget(
        buildScreen(
          eventId: 'event-1',
          load: () async =>
              ParticipantSummaryState(event: event, participants: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Campus Hackathon'), findsOneWidget);
      expect(find.text('Event ID: event-1'), findsOneWidget);
      expect(find.byKey(const Key('emptyParticipantsMessage')), findsOneWidget);
      expect(
        find.text('No participants have registered for this event yet.'),
        findsOneWidget,
      );

      // Stat cards
      expect(find.text('0 / 100'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('renders participants list and statistics accurately', (
      tester,
    ) async {
      final event = testEvent(
        id: 'event-1',
        title: 'Flutter Workshop',
        capacity: 100,
        registeredCount: 4,
        checkedInCount: 2,
      );

      final participants = [
        testRegistration(
          id: 'reg-1',
          eventId: 'event-1',
          userId: 'student-alpha',
          status: RegistrationStatus.checkedIn,
          checkedInAt: DateTime.utc(2030, 5, 20, 9, 30),
        ),
        testRegistration(
          id: 'reg-2',
          eventId: 'event-1',
          userId: 'student-beta',
          status: RegistrationStatus.registered,
        ),
      ];

      await tester.pumpWidget(
        buildScreen(
          eventId: 'event-1',
          load: () async =>
              ParticipantSummaryState(event: event, participants: participants),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flutter Workshop'), findsOneWidget);
      expect(find.text('4 / 100'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('50.0%'), findsOneWidget);

      expect(find.text('User: student-alpha'), findsOneWidget);
      expect(find.text('User: student-beta'), findsOneWidget);
      expect(find.text('Đã check-in'), findsOneWidget);
      expect(find.text('Đã đăng ký'), findsOneWidget);
    });

    testWidgets('renders error state with retry button and recovers on retry', (
      tester,
    ) async {
      var shouldFail = true;
      final event = testEvent(id: 'event-1');

      await tester.pumpWidget(
        buildScreen(
          eventId: 'event-1',
          load: () async {
            if (shouldFail) {
              throw const AppException(
                'Unable to load participants.',
                code: 'network-error',
              );
            }
            return ParticipantSummaryState(
              event: event,
              participants: const [],
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('participantSummaryError')), findsOneWidget);
      expect(find.text('Unable to load participants.'), findsOneWidget);
      expect(
        find.byKey(const Key('participantSummaryRetryButton')),
        findsOneWidget,
      );

      // Now retry
      shouldFail = false;
      await tester.tap(find.byKey(const Key('participantSummaryRetryButton')));
      await tester.pumpAndSettle();

      expect(find.text('Flutter Workshop'), findsOneWidget);
      expect(find.byKey(const Key('emptyParticipantsMessage')), findsOneWidget);
    });

    testWidgets('renders permission denied error properly', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          eventId: 'event-1',
          load: () async => throw const AppException(
            'You can only view participants for events you manage.',
            code: 'event-forbidden',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('You can only view participants for events you manage.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('emptyParticipantsMessage')), findsNothing);
    });

    testWidgets('refresh button triggers provider reload', (tester) async {
      var callCount = 0;
      final event = testEvent(id: 'event-1');

      await tester.pumpWidget(
        buildScreen(
          eventId: 'event-1',
          load: () async {
            callCount++;
            return ParticipantSummaryState(
              event: event,
              participants: const [],
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(callCount, 1);

      await tester.tap(
        find.byKey(const Key('participantSummaryRefreshButton')),
      );
      await tester.pumpAndSettle();
      expect(callCount, 2);
    });

    testWidgets(
      'responsive layout does not overflow on mobile portrait, landscape and tablet',
      (tester) async {
        final event = testEvent(
          id: 'event-1',
          title: 'Very Long Title For An Event Campus Hackathon Workshop 2030',
          capacity: 500,
          registeredCount: 250,
          checkedInCount: 125,
        );

        final state = ParticipantSummaryState(
          event: event,
          participants: [
            testRegistration(
              id: 'r1',
              eventId: 'event-1',
              userId: 'student-super-long-identifier-12345',
              status: RegistrationStatus.checkedIn,
              checkedInAt: DateTime.utc(2030, 5, 20, 10, 0),
            ),
          ],
        );

        // Mobile portrait
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          buildScreen(eventId: 'event-1', load: () async => state),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Mobile landscape
        tester.view.physicalSize = const Size(844 * 3, 390 * 3);
        await tester.pumpWidget(
          buildScreen(eventId: 'event-1', load: () async => state),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Tablet
        tester.view.physicalSize = const Size(1024 * 2, 768 * 2);
        tester.view.devicePixelRatio = 2.0;
        await tester.pumpWidget(
          buildScreen(eventId: 'event-1', load: () async => state),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

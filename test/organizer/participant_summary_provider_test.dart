import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/participant_summary_view_model.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import '../registration/registration_fakes.dart';

void main() {
  group('ParticipantSummaryState', () {
    test('computes attendance rate accurately and avoids zero-division', () {
      final zeroRegisteredEvent = testEvent(
        id: 'e0',
        capacity: 100,
        registeredCount: 0,
        checkedInCount: 0,
      );
      final zeroState = ParticipantSummaryState(
        event: zeroRegisteredEvent,
        participants: const [],
      );
      expect(zeroState.registeredCount, 0);
      expect(zeroState.checkedInCount, 0);
      expect(zeroState.attendanceRate, 0.0);

      final event = testEvent(
        id: 'e1',
        capacity: 100,
        registeredCount: 20,
        checkedInCount: 5,
      );
      final state = ParticipantSummaryState(
        event: event,
        participants: [
          testRegistration(id: 'r1', eventId: 'e1', userId: 'u1'),
          testRegistration(
            id: 'r2',
            eventId: 'e1',
            userId: 'u2',
            status: RegistrationStatus.checkedIn,
            checkedInAt: DateTime.utc(2030, 5, 20, 9, 30),
          ),
        ],
      );
      expect(state.registeredCount, 20);
      expect(state.checkedInCount, 5);
      expect(state.attendanceRate, 25.0);
    });
  });

  group('participantSummaryProvider', () {
    late FakeEvents fakeEvents;
    late FakeRegistrationRepository fakeRegistrations;

    setUp(() {
      fakeEvents = FakeEvents([
        testEvent(
          id: 'event-owner-1',
          organizerId: 'org-1',
          title: 'Owner Event',
          registeredCount: 2,
          checkedInCount: 1,
        ),
        testEvent(
          id: 'event-owner-2',
          organizerId: 'org-2',
          title: 'Other Organizer Event',
          registeredCount: 1,
          checkedInCount: 0,
        ),
      ]);
      fakeRegistrations = FakeRegistrationRepository([
        testRegistration(
          id: 'reg-1',
          eventId: 'event-owner-1',
          userId: 'student-1',
          status: RegistrationStatus.checkedIn,
          checkedInAt: DateTime.utc(2030, 5, 20, 9, 15),
        ),
        testRegistration(
          id: 'reg-2',
          eventId: 'event-owner-1',
          userId: 'student-2',
          status: RegistrationStatus.registered,
        ),
        testRegistration(
          id: 'reg-3',
          eventId: 'event-owner-2',
          userId: 'student-3',
          status: RegistrationStatus.registered,
        ),
      ]);
    });

    Widget createTestHarness({
      required String eventId,
      String uid = 'org-1',
      UserRole role = UserRole.organizer,
      String status = 'active',
      required void Function(AsyncValue<ParticipantSummaryState> state) onState,
    }) {
      return ProviderScope(
        retry: (_, _) => null,
        overrides: [
          currentUserProvider.overrideWith(
            (ref) =>
                Stream.value(testUser(uid: uid, role: role, status: status)),
          ),
          eventRepositoryProvider.overrideWithValue(fakeEvents),
          registrationRepositoryProvider.overrideWithValue(fakeRegistrations),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(participantSummaryProvider(eventId));
            onState(state);
            return const SizedBox();
          },
        ),
      );
    }

    testWidgets('loads participant summary successfully for event owner', (
      tester,
    ) async {
      ParticipantSummaryState? summary;
      await tester.pumpWidget(
        createTestHarness(
          eventId: 'event-owner-1',
          uid: 'org-1',
          onState: (state) {
            if (state.hasValue) summary = state.value;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(summary, isNotNull);
      expect(summary!.event.id, 'event-owner-1');
      expect(summary!.event.title, 'Owner Event');
      expect(summary!.participants.length, 2);
      expect(summary!.registeredCount, 2);
      expect(summary!.checkedInCount, 1);
      expect(summary!.attendanceRate, 50.0);
    });

    testWidgets('admin can view participants of any event', (tester) async {
      ParticipantSummaryState? summary;
      await tester.pumpWidget(
        createTestHarness(
          eventId: 'event-owner-1',
          uid: 'admin-1',
          role: UserRole.admin,
          onState: (state) {
            if (state.hasValue) summary = state.value;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(summary, isNotNull);
      expect(summary!.event.id, 'event-owner-1');
      expect(summary!.participants.length, 2);
    });

    testWidgets('student role is forbidden from viewing participants', (
      tester,
    ) async {
      Object? error;
      await tester.pumpWidget(
        createTestHarness(
          eventId: 'event-owner-1',
          uid: 'student-1',
          role: UserRole.student,
          onState: (state) {
            if (state.hasError) error = state.error;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        error,
        isA<AppException>().having((e) => e.code, 'code', 'event-forbidden'),
      );
    });

    testWidgets('inactive organizer is forbidden from viewing participants', (
      tester,
    ) async {
      Object? error;
      await tester.pumpWidget(
        createTestHarness(
          eventId: 'event-owner-1',
          uid: 'org-1',
          role: UserRole.organizer,
          status: 'disabled',
          onState: (state) {
            if (state.hasError) error = state.error;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        error,
        isA<AppException>().having((e) => e.code, 'code', 'event-forbidden'),
      );
    });

    testWidgets(
      'organizer B cannot view participants of event owned by organizer A',
      (tester) async {
        Object? error;
        await tester.pumpWidget(
          createTestHarness(
            eventId: 'event-owner-1',
            uid: 'org-2',
            role: UserRole.organizer,
            onState: (state) {
              if (state.hasError) error = state.error;
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(
          error,
          isA<AppException>().having((e) => e.code, 'code', 'event-forbidden'),
        );
      },
    );

    testWidgets('fails with event-not-found when event does not exist', (
      tester,
    ) async {
      Object? error;
      await tester.pumpWidget(
        createTestHarness(
          eventId: 'non-existent-event',
          uid: 'org-1',
          onState: (state) {
            if (state.hasError) error = state.error;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(
        error,
        isA<AppException>().having((e) => e.code, 'code', 'event-not-found'),
      );
    });

    testWidgets('isolates participant data between different event IDs', (
      tester,
    ) async {
      ParticipantSummaryState? summary1;
      ParticipantSummaryState? summary2;

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            currentUserProvider.overrideWith(
              (ref) =>
                  Stream.value(testUser(uid: 'admin-1', role: UserRole.admin)),
            ),
            eventRepositoryProvider.overrideWithValue(fakeEvents),
            registrationRepositoryProvider.overrideWithValue(fakeRegistrations),
          ],
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final s = ref.watch(
                    participantSummaryProvider('event-owner-1'),
                  );
                  if (s.hasValue) summary1 = s.value;
                  return const SizedBox();
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final s = ref.watch(
                    participantSummaryProvider('event-owner-2'),
                  );
                  if (s.hasValue) summary2 = s.value;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(summary1, isNotNull);
      expect(summary2, isNotNull);
      expect(summary1!.participants.map((p) => p.id), ['reg-1', 'reg-2']);
      expect(summary2!.participants.map((p) => p.id), ['reg-3']);
    });
  });
}

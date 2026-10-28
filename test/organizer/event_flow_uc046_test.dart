import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/participant_summary_view_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import 'event_form_view_model_test.dart' show validInput;

void main() {
  test(
    'real Dart repositories connect create/edit/feed/join/check-in/refreshed summary/cancel',
    () async {
      final db = FakeFirebaseFirestore();
      final owner = testUser(uid: 'owner', role: UserRole.organizer);
      final student = testUser(uid: 'student', role: UserRole.student);
      var actor = owner;
      await db.collection('users').doc(owner.uid).set(owner.toMap());
      final events = EventRepositoryImpl(
        firestore: db,
        authenticatedActor: () async => actor,
      );
      final registrations = RegistrationRepositoryImpl(
        db,
        null,
        () async => actor,
      );
      final now = DateTime.now().toUtc();
      final input = validInput().copyWith(
        startAt: now.add(const Duration(days: 1)),
        endAt: now.add(const Duration(days: 1, hours: 2)),
        capacity: 2,
        createRequestId: 'persisted-request',
      );
      final created = await events.createEvent(input: input, actor: owner);
      final container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWith((ref) => Stream.value(owner)),
          eventRepositoryProvider.overrideWithValue(events),
          registrationRepositoryProvider.overrideWithValue(registrations),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        participantSummaryProvider(created.id),
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        (await container.read(
          participantSummaryProvider(created.id).future,
        )).registeredCount,
        0,
      );
      actor = student;
      expect((await events.getUpcomingEvents()).single.id, created.id);
      final ticket = await registrations.joinEvent(
        eventId: created.id,
        userId: student.uid,
      );
      await expectLater(
        registrations.joinEvent(eventId: created.id, userId: student.uid),
        throwsException,
      );
      actor = owner;
      final joined = await container.refresh(
        participantSummaryProvider(created.id).future,
      );
      expect(joined.registeredCount, 1);
      expect(joined.participants.single.userId, student.uid);
      await events.updateEvent(
        eventId: created.id,
        actor: owner,
        input: input.copyWith(
          title: 'Updated campus workshop',
          locationName: 'Hall B',
        ),
      );
      final edited = await events.getEventById(created.id);
      expect(edited.title, 'Updated campus workshop');
      expect(edited.locationName, 'Hall B');
      expect(edited.registeredCount, 1);
      final payload = QrPayload(
        eventId: created.id,
        registrationId: ticket.id,
        token: ticket.qrToken,
      );
      await registrations.checkIn(organizerId: owner.uid, payload: payload);
      await expectLater(
        registrations.checkIn(organizerId: owner.uid, payload: payload),
        throwsException,
      );
      final summary = await container.refresh(
        participantSummaryProvider(created.id).future,
      );
      expect(summary.registeredCount, 1);
      expect(summary.checkedInCount, 1);
      expect(summary.notYetCheckedInCount, 0);
      expect(summary.attendanceRate, 100);
      expect(summary.participants.single.status, RegistrationStatus.checkedIn);
      await events.cancelEvent(eventId: created.id, actor: owner);
      expect(await events.getUpcomingEvents(forceRefresh: true), isEmpty);
      expect(
        await registrations.getEventParticipants(created.id),
        hasLength(1),
      );
    },
  );

  test(
    'persisted request recovers same event after repository recreation without resetting counters',
    () async {
      final db = FakeFirebaseFirestore();
      final owner = testUser(uid: 'owner', role: UserRole.organizer);
      final now = DateTime.utc(2029);
      final input = validInput().copyWith(createRequestId: 'durable-request');
      final first = EventRepositoryImpl(firestore: db, now: () => now);
      final event = await first.createEvent(input: input, actor: owner);
      await db.collection('events').doc(event.id).update({
        'registeredCount': 1,
        'checkedInCount': 1,
      });
      final reopened = EventRepositoryImpl(firestore: db, now: () => now);
      final recovered = await reopened.createEvent(
        input: input.copyWith(title: 'Recovered edited workshop'),
        actor: owner,
      );
      expect(recovered.id, event.id);
      expect(recovered.registeredCount, 1);
      expect(recovered.checkedInCount, 1);
      expect(recovered.title, 'Recovered edited workshop');
      expect((await db.collection('events').get()).docs, hasLength(1));
    },
  );
}

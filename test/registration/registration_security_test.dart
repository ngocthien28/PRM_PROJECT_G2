import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

class _FailingFirestore extends FakeFirebaseFirestore {
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

void main() {
  late FakeFirebaseFirestore db;
  late RegistrationRepositoryImpl repository;
  AppUser? actual;
  setUp(() async {
    actual = testUser(uid: 'student');
    db = FakeFirebaseFirestore();
    repository = RegistrationRepositoryImpl(db, null, () async => actual);
    await db
        .collection('events')
        .doc('event-1')
        .set(
          testEvent(
            startAt: DateTime.now().toUtc().add(const Duration(days: 1)),
            registeredCount: 0,
          ).toMap(),
        );
    for (final uid in ['organizer-1', 'other', 'admin']) {
      await db
          .collection('users')
          .doc(uid)
          .set(
            testUser(
              uid: uid,
              role: uid == 'admin' ? UserRole.admin : UserRole.organizer,
            ).toMap(),
          );
    }
  });
  test(
    'Firebase rejection never returns a fabricated successful registration',
    () async {
      final denied = RegistrationRepositoryImpl(_FailingFirestore());
      await expectLater(
        denied.joinEvent(eventId: 'event-1', userId: 'student'),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );
  test(
    'join, cancellation and rejoin keep the deterministic ID and correct count',
    () async {
      final joined = await repository.joinEvent(
        eventId: 'event-1',
        userId: 'student',
      );
      expect(joined.id, 'event-1_student');
      expect(
        (await db.collection('events').doc('event-1').get())
            .data()!['registeredCount'],
        1,
      );
      await repository.cancelRegistration(
        registrationId: joined.id,
        userId: 'student',
      );
      expect(
        (await db.collection('events').doc('event-1').get())
            .data()!['registeredCount'],
        0,
      );
      await repository.joinEvent(eventId: 'event-1', userId: 'student');
      expect((await db.collection('registrations').get()).docs, hasLength(1));
      expect(
        (await db.collection('events').doc('event-1').get())
            .data()!['registeredCount'],
        1,
      );
    },
  );
  test(
    'owner/admin check-in writes reciprocal marker and cannot be replayed as a join',
    () async {
      final joined = await repository.joinEvent(
        eventId: 'event-1',
        userId: 'student',
      );
      actual = testUser(uid: 'admin', role: UserRole.admin);
      final checked = await repository.checkIn(
        organizerId: 'admin',
        payload: joined.payload,
      );
      expect(checked.status, RegistrationStatus.checkedIn);
      final event = (await db.collection('events').doc('event-1').get())
          .data()!;
      expect(event['checkedInCount'], 1);
      expect(event['lastCheckInRegistrationId'], joined.id);
      expect(
        (await db.collection('registrations').doc(joined.id).get())
            .data()!['checkedInAt'],
        isA<Timestamp>(),
      );
      actual = testUser(uid: 'student');
      await expectLater(
        repository.joinEvent(eventId: 'event-1', userId: 'student'),
        throwsA(isA<AppException>()),
      );
      expect(
        (await db.collection('events').doc('event-1').get())
            .data()!['registeredCount'],
        1,
      );
    },
  );
  test(
    'other organizer cannot read participants or check in a foreign event',
    () async {
      final joined = await repository.joinEvent(
        eventId: 'event-1',
        userId: 'student',
      );
      actual = testUser(uid: 'other', role: UserRole.organizer);
      await expectLater(
        repository.getEventParticipants('event-1'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.checkIn(organizerId: 'other', payload: joined.payload),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.checkIn(organizerId: 'organizer-1', payload: joined.payload),
        throwsA(isA<AppException>()),
      );
      actual = testUser(uid: 'organizer-1', role: UserRole.organizer);
      expect(await repository.getEventParticipants('event-1'), hasLength(1));
    },
  );
  test(
    'personal reads/writes cannot spoof another user or use an expired session',
    () async {
      await expectLater(
        repository.getMyRegistrations('other'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.getRegistration('event-1', 'other'),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.joinEvent(eventId: 'event-1', userId: 'other'),
        throwsA(isA<AppException>()),
      );
      actual = null;
      await expectLater(
        repository.getMyRegistrations('student'),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'identity verification failure maps to AppException without a write',
    () async {
      final failedIdentity = RegistrationRepositoryImpl(db, null, () async {
        throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      });
      await expectLater(
        failedIdentity.joinEvent(eventId: 'event-1', userId: 'student'),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );
      expect((await db.collection('registrations').get()).docs, isEmpty);
    },
  );
}

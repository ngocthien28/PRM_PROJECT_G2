import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RegistrationRepositoryImpl repository;

  final studentUser = AppUser(
    uid: 'student_123',
    email: 'student@fpt.edu.vn',
    displayName: 'Thái Student',
    role: UserRole.student,
    status: 'active',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = RegistrationRepositoryImpl(
      fakeFirestore,
      null,
      () async => studentUser,
    );
  });

  group('UC-052: Cancel Event Registration Tests', () {
    test('successfully cancels registration before cutoff and decrements count', () async {
      // Event starting tomorrow (> 2 hours in the future)
      final futureEvent = EventModel(
        id: 'event_tech_01',
        organizerId: 'org_001',
        title: 'Flutter Forward',
        description: 'Deep dive into advanced mobile development architectures.',
        category: 'technology',
        locationName: 'Hall A',
        startAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        endAt: DateTime.now().toUtc().add(const Duration(days: 1, hours: 2)),
        capacity: 100,
        registeredCount: 1,
        checkedInCount: 0,
        status: EventStatus.published,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await fakeFirestore
          .collection('events')
          .doc(futureEvent.id)
          .set(futureEvent.toMap());

      const regId = 'event_tech_01_student_123';
      final registration = RegistrationModel(
        id: regId,
        eventId: futureEvent.id,
        userId: studentUser.uid,
        status: RegistrationStatus.registered,
        qrToken: 'test-qr-token-123',
        registeredAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );

      await fakeFirestore
          .collection('registrations')
          .doc(regId)
          .set(registration.toMap());

      // Execute cancellation
      await repository.cancelRegistration(
        registrationId: regId,
        userId: studentUser.uid,
      );

      // Verify Firestore state
      final updatedRegDoc = await fakeFirestore
          .collection('registrations')
          .doc(regId)
          .get();
      final updatedEventDoc = await fakeFirestore
          .collection('events')
          .doc(futureEvent.id)
          .get();

      expect(updatedRegDoc.data()?['status'], RegistrationStatus.cancelled.name);
      expect(updatedRegDoc.data()?['cancelledAt'], isNotNull);
      expect(updatedEventDoc.data()?['registeredCount'], 0);
    });

    test('rejects cancellation when within 2 hours of event start (BR-07 cutoff rule)', () async {
      // Event starting in 1 hour (< 2 hour cutoff)
      final imminentEvent = EventModel(
        id: 'event_imminent_02',
        organizerId: 'org_001',
        title: 'Imminent Workshop',
        description: 'Starting in less than 2 hours.',
        category: 'workshop',
        locationName: 'Room 301',
        startAt: DateTime.now().toUtc().add(const Duration(minutes: 60)),
        endAt: DateTime.now().toUtc().add(const Duration(hours: 3)),
        capacity: 50,
        registeredCount: 1,
        checkedInCount: 0,
        status: EventStatus.published,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await fakeFirestore
          .collection('events')
          .doc(imminentEvent.id)
          .set(imminentEvent.toMap());

      const regId = 'event_imminent_02_student_123';
      final registration = RegistrationModel(
        id: regId,
        eventId: imminentEvent.id,
        userId: studentUser.uid,
        status: RegistrationStatus.registered,
        qrToken: 'test-token-456',
        registeredAt: DateTime.now().toUtc().subtract(const Duration(hours: 2)),
      );

      await fakeFirestore
          .collection('registrations')
          .doc(regId)
          .set(registration.toMap());

      expect(
        () => repository.cancelRegistration(
          registrationId: regId,
          userId: studentUser.uid,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('ít nhất 2 giờ'),
          ),
        ),
      );

      // Registration remains registered
      final doc = await fakeFirestore.collection('registrations').doc(regId).get();
      expect(doc.data()?['status'], RegistrationStatus.registered.name);
    });

    test('rejects cancellation when ticket is already checked in', () async {
      final event = EventModel(
        id: 'event_checked_03',
        organizerId: 'org_001',
        title: 'Live Concert',
        description: 'Musical festival on the central campus quad.',
        category: 'music',
        locationName: 'Campus Quad',
        startAt: DateTime.now().toUtc().add(const Duration(days: 3)),
        endAt: DateTime.now().toUtc().add(const Duration(days: 3, hours: 4)),
        capacity: 200,
        registeredCount: 1,
        checkedInCount: 1,
        status: EventStatus.published,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      await fakeFirestore.collection('events').doc(event.id).set(event.toMap());

      const regId = 'event_checked_03_student_123';
      final checkedInRegistration = RegistrationModel(
        id: regId,
        eventId: event.id,
        userId: studentUser.uid,
        status: RegistrationStatus.checkedIn,
        qrToken: 'test-token-789',
        registeredAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        checkedInAt: DateTime.now().toUtc().subtract(const Duration(minutes: 10)),
      );

      await fakeFirestore
          .collection('registrations')
          .doc(regId)
          .set(checkedInRegistration.toMap());

      expect(
        () => repository.cancelRegistration(
          registrationId: regId,
          userId: studentUser.uid,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('đã được check-in'),
          ),
        ),
      );
    });

    test('rejects cancellation if user does not own the registration', () async {
      const regId = 'event_tech_01_other_user';
      final otherRegistration = RegistrationModel(
        id: regId,
        eventId: 'event_tech_01',
        userId: 'other_user_999',
        status: RegistrationStatus.registered,
        qrToken: 'token-other',
        registeredAt: DateTime.now().toUtc(),
      );

      await fakeFirestore
          .collection('registrations')
          .doc(regId)
          .set(otherRegistration.toMap());

      expect(
        () => repository.cancelRegistration(
          registrationId: regId,
          userId: 'other_user_999',
        ),
        throwsA(isA<AppException>()),
      );
    });
  });
}

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late RegistrationRepositoryImpl repository;
  AppUser? currentActor;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = RegistrationRepositoryImpl(
      fakeFirestore,
      null,
      () async => currentActor,
    );
  });

  group('UC-059: Enforce Registration Business Rules', () {
    const studentId = 'student_001';
    final student = testUser(uid: studentId, role: UserRole.student);

    setUp(() async {
      currentActor = student;
      await fakeFirestore
          .collection('users')
          .doc(studentId)
          .set(student.toMap());
    });

    test('TC-R01: Student successfully registers for available event', () async {
      final event = testEvent(
        id: 'event_open',
        capacity: 50,
        registeredCount: 10,
        startAt: DateTime.now().toUtc().add(const Duration(days: 3)),
        status: EventStatus.published,
      );
      await fakeFirestore
          .collection('events')
          .doc(event.id)
          .set(event.toMap());

      final registration = await repository.joinEvent(
        eventId: event.id,
        userId: studentId,
      );

      expect(registration.eventId, event.id);
      expect(registration.userId, studentId);
      expect(registration.status, RegistrationStatus.registered);
      expect(registration.qrToken, isNotEmpty);

      // Verify Firestore update
      final regDoc = await fakeFirestore
          .collection('registrations')
          .doc('${event.id}_$studentId')
          .get();
      expect(regDoc.exists, isTrue);

      final eventDoc = await fakeFirestore
          .collection('events')
          .doc(event.id)
          .get();
      expect(eventDoc.data()?['registeredCount'], 11);
    });

    test('TC-R02: Duplicate registration is blocked if already registered', () async {
      final event = testEvent(
        id: 'event_dup',
        startAt: DateTime.now().toUtc().add(const Duration(days: 2)),
      );
      await fakeFirestore
          .collection('events')
          .doc(event.id)
          .set(event.toMap());

      // First registration
      await repository.joinEvent(
        eventId: event.id,
        userId: studentId,
      );

      // Second registration attempt should fail
      expect(
        () => repository.joinEvent(
          eventId: event.id,
          userId: studentId,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Bạn đã đăng ký tham gia sự kiện này rồi'),
          ),
        ),
      );
    });

    test('TC-R03: Registration is blocked when event capacity is full', () async {
      final fullEvent = testEvent(
        id: 'event_full',
        capacity: 30,
        registeredCount: 30,
        startAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      );
      await fakeFirestore
          .collection('events')
          .doc(fullEvent.id)
          .set(fullEvent.toMap());

      expect(
        () => repository.joinEvent(
          eventId: fullEvent.id,
          userId: studentId,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Hết chỗ'),
          ),
        ),
      );
    });

    test('Registration is blocked when event start time has already passed', () async {
      final pastEvent = testEvent(
        id: 'event_past',
        startAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)),
      );
      await fakeFirestore
          .collection('events')
          .doc(pastEvent.id)
          .set(pastEvent.toMap());

      expect(
        () => repository.joinEvent(
          eventId: pastEvent.id,
          userId: studentId,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Sự kiện đã bắt đầu hoặc quá thời hạn đăng ký'),
          ),
        ),
      );
    });

    test('Registration is blocked when event is not published (draft or cancelled)', () async {
      final cancelledEvent = testEvent(
        id: 'event_cancelled',
        status: EventStatus.cancelled,
        startAt: DateTime.now().toUtc().add(const Duration(days: 2)),
      );
      await fakeFirestore
          .collection('events')
          .doc(cancelledEvent.id)
          .set(cancelledEvent.toMap());

      expect(
        () => repository.joinEvent(
          eventId: cancelledEvent.id,
          userId: studentId,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Sự kiện hiện không mở đăng ký'),
          ),
        ),
      );
    });

    test('Registration is blocked when user account is inactive', () async {
      final inactiveStudent = testUser(
        uid: 'inactive_student',
        role: UserRole.student,
        status: 'disabled',
      );
      currentActor = inactiveStudent;

      final event = testEvent(
        id: 'event_active_test',
        startAt: DateTime.now().toUtc().add(const Duration(days: 2)),
      );
      await fakeFirestore
          .collection('events')
          .doc(event.id)
          .set(event.toMap());

      expect(
        () => repository.joinEvent(
          eventId: event.id,
          userId: inactiveStudent.uid,
        ),
        throwsA(isA<AppException>()),
      );
    });

    test('Re-registration after cancellation is allowed and increments count', () async {
      final event = testEvent(
        id: 'event_rejoin',
        capacity: 20,
        registeredCount: 5,
        startAt: DateTime.now().toUtc().add(const Duration(days: 4)),
      );
      await fakeFirestore
          .collection('events')
          .doc(event.id)
          .set(event.toMap());

      // Initial registration
      await repository.joinEvent(
        eventId: event.id,
        userId: studentId,
      );

      // Cancel registration
      await repository.cancelRegistration(
        registrationId: '${event.id}_$studentId',
        userId: studentId,
      );

      // Re-register
      final reRegistered = await repository.joinEvent(
        eventId: event.id,
        userId: studentId,
      );

      expect(reRegistered.status, RegistrationStatus.registered);

      final eventDoc = await fakeFirestore
          .collection('events')
          .doc(event.id)
          .get();
      // Initially 5 -> joined: 6 -> cancelled: 5 -> re-joined: 6
      expect(eventDoc.data()?['registeredCount'], 6);
    });
  });

  group('UC-059: Enforce QR Check-in Business Rules', () {
    const organizerId = 'org_primary';
    const otherOrganizerId = 'org_secondary';
    const studentId = 'student_001';
    const eventId = 'event_checkin_001';

    final organizer = testUser(uid: organizerId, role: UserRole.organizer);
    final otherOrganizer = testUser(uid: otherOrganizerId, role: UserRole.organizer);

    late EventModel activeEvent;
    late RegistrationModel validRegistration;

    setUp(() async {
      currentActor = organizer;

      // Seed organizer users
      await fakeFirestore
          .collection('users')
          .doc(organizerId)
          .set(organizer.toMap());
      await fakeFirestore
          .collection('users')
          .doc(otherOrganizerId)
          .set(otherOrganizer.toMap());

      // Seed active event managed by organizerId
      activeEvent = testEvent(
        id: eventId,
        organizerId: organizerId,
        title: 'Tech Summit 2026',
        capacity: 100,
        registeredCount: 50,
        checkedInCount: 0,
        startAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        status: EventStatus.published,
      );
      await fakeFirestore
          .collection('events')
          .doc(eventId)
          .set(activeEvent.toMap());

      // Seed valid registration
      validRegistration = RegistrationModel(
        id: '${eventId}_$studentId',
        eventId: eventId,
        userId: studentId,
        status: RegistrationStatus.registered,
        qrToken: 'valid-secure-qr-token-999',
        registeredAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
      );
      await fakeFirestore
          .collection('registrations')
          .doc(validRegistration.id)
          .set(validRegistration.toMap());
    });

    test('TC-Q01: Valid QR scan successfully checks in participant', () async {
      final payload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: eventId,
        token: 'valid-secure-qr-token-999',
      );

      final checkedIn = await repository.checkIn(
        organizerId: organizerId,
        payload: payload,
      );

      expect(checkedIn.status, RegistrationStatus.checkedIn);
      expect(checkedIn.checkedInAt, isNotNull);

      // Verify Firestore updates
      final regDoc = await fakeFirestore
          .collection('registrations')
          .doc(validRegistration.id)
          .get();
      expect(regDoc.data()?['status'], RegistrationStatus.checkedIn.name);
      expect(regDoc.data()?['checkedInAt'], isNotNull);

      final eventDoc = await fakeFirestore
          .collection('events')
          .doc(eventId)
          .get();
      expect(eventDoc.data()?['checkedInCount'], 1);
      expect(eventDoc.data()?['lastCheckInRegistrationId'], validRegistration.id);
    });

    test('TC-Q02: Duplicate check-in is rejected', () async {
      final payload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: eventId,
        token: 'valid-secure-qr-token-999',
      );

      // First scan passes
      await repository.checkIn(
        organizerId: organizerId,
        payload: payload,
      );

      // Second scan fails with duplicate check-in message
      expect(
        () => repository.checkIn(
          organizerId: organizerId,
          payload: payload,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Vé này đã được check-in trước đó (Quét trùng)'),
          ),
        ),
      );
    });

    test('TC-Q03: Wrong event QR code is rejected', () async {
      // Payload has a different eventId
      const wrongEventId = 'event_other_diff';
      final wrongEventPayload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: wrongEventId,
        token: 'valid-secure-qr-token-999',
      );

      expect(
        () => repository.checkIn(
          organizerId: organizerId,
          payload: wrongEventPayload,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Mã QR không hợp lệ hoặc sai sự kiện'),
          ),
        ),
      );
    });

    test('Invalid QR token is rejected when token does not match registration', () async {
      final tamperedPayload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: eventId,
        token: 'tampered-or-fake-token',
      );

      expect(
        () => repository.checkIn(
          organizerId: organizerId,
          payload: tamperedPayload,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Mã QR không hợp lệ hoặc sai sự kiện'),
          ),
        ),
      );
    });

    test('Cancelled ticket cannot be checked in', () async {
      // Mark registration as cancelled
      await fakeFirestore
          .collection('registrations')
          .doc(validRegistration.id)
          .update({'status': RegistrationStatus.cancelled.name});

      final payload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: eventId,
        token: 'valid-secure-qr-token-999',
      );

      expect(
        () => repository.checkIn(
          organizerId: organizerId,
          payload: payload,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('Vé không ở trạng thái hoạt động để check-in'),
          ),
        ),
      );
    });

    test('Unauthorized organizer cannot check in participants of another organizer', () async {
      currentActor = otherOrganizer;

      final payload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: eventId,
        token: 'valid-secure-qr-token-999',
      );

      expect(
        () => repository.checkIn(
          organizerId: otherOrganizerId,
          payload: payload,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'event-forbidden',
          ),
        ),
      );
    });

    test('Check-in is rejected when event is cancelled', () async {
      // Set event status to cancelled
      await fakeFirestore
          .collection('events')
          .doc(eventId)
          .update({'status': EventStatus.cancelled.name});

      final payload = QrPayload(
        version: 1,
        registrationId: validRegistration.id,
        eventId: eventId,
        token: 'valid-secure-qr-token-999',
      );

      expect(
        () => repository.checkIn(
          organizerId: organizerId,
          payload: payload,
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'event-cancelled',
          ),
        ),
      );
    });
  });
}

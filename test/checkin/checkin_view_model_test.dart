import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/checkin/presentation/viewmodels/checkin_view_model.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late ProviderContainer container;

  final organizerUser = AppUser(
    uid: 'organizer_host_01',
    email: 'organizer@fpt.edu.vn',
    displayName: 'Thái Organizer',
    role: UserRole.organizer,
    status: 'active',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final studentAttendee = AppUser(
    uid: 'student_attendee_01',
    email: 'student_attendee@fpt.edu.vn',
    displayName: 'Nguyễn Văn A',
    role: UserRole.student,
    status: 'active',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  late EventModel testEvent;
  late RegistrationModel testRegistration;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();

    // Seed users in Firestore
    await fakeFirestore
        .collection('users')
        .doc(organizerUser.uid)
        .set(organizerUser.toMap());
    await fakeFirestore
        .collection('users')
        .doc(studentAttendee.uid)
        .set(studentAttendee.toMap());

    // Seed test event
    testEvent = EventModel(
      id: 'event_gdg_2026',
      organizerId: organizerUser.uid,
      title: 'GDG DevFest 2026',
      description: 'The premier campus developer festival featuring Google technologies.',
      category: 'technology',
      locationName: 'Auditorium A',
      startAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      endAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
      capacity: 100,
      registeredCount: 1,
      checkedInCount: 0,
      status: EventStatus.published,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    await fakeFirestore
        .collection('events')
        .doc(testEvent.id)
        .set(testEvent.toMap());

    // Seed active registration
    testRegistration = RegistrationModel(
      id: '${testEvent.id}_${studentAttendee.uid}',
      eventId: testEvent.id,
      userId: studentAttendee.uid,
      status: RegistrationStatus.registered,
      qrToken: 'valid-qr-uuid-secret-token',
      registeredAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
    );
    await fakeFirestore
        .collection('registrations')
        .doc(testRegistration.id)
        .set(testRegistration.toMap());

    final repo = RegistrationRepositoryImpl(
      fakeFirestore,
      null,
      () async => organizerUser,
    );

    container = ProviderContainer(
      overrides: [
        firestoreProvider.overrideWithValue(fakeFirestore),
        registrationRepositoryProvider.overrideWithValue(repo),
        currentUserProvider.overrideWithValue(AsyncData(organizerUser)),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('UC-057: CheckinViewModel Tests', () {
    test('successfully checks in participant with valid QR payload', () async {
      final viewModel = container.read(checkinViewModelProvider.notifier);

      final validPayload = const QrPayload(
        version: 1,
        registrationId: 'event_gdg_2026_student_attendee_01',
        eventId: 'event_gdg_2026',
        token: 'valid-qr-uuid-secret-token',
      ).encode();

      final result = await viewModel.processBarcode(
        validPayload,
        expectedEventId: 'event_gdg_2026',
        expectedEventTitle: 'GDG DevFest 2026',
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, contains('thành công'));
      expect(result.participantName, 'Nguyễn Văn A');
      expect(result.participantEmail, 'student_attendee@fpt.edu.vn');
      expect(result.registration?.status, RegistrationStatus.checkedIn);
      expect(result.registration?.checkedInAt, isNotNull);

      // Verify Firestore persisted update
      final regDoc = await fakeFirestore
          .collection('registrations')
          .doc(testRegistration.id)
          .get();
      expect(regDoc.data()?['status'], RegistrationStatus.checkedIn.name);
      expect(regDoc.data()?['checkedInAt'], isNotNull);

      final eventDoc = await fakeFirestore
          .collection('events')
          .doc(testEvent.id)
          .get();
      expect(eventDoc.data()?['checkedInCount'], 1);
      expect(eventDoc.data()?['lastCheckInRegistrationId'], testRegistration.id);
    });

    test('enforces duplicate check-in prevention (TC-Q02)', () async {
      final viewModel = container.read(checkinViewModelProvider.notifier);

      final validPayload = const QrPayload(
        version: 1,
        registrationId: 'event_gdg_2026_student_attendee_01',
        eventId: 'event_gdg_2026',
        token: 'valid-qr-uuid-secret-token',
      ).encode();

      // First check-in: Success
      final firstResult = await viewModel.processBarcode(
        validPayload,
        expectedEventId: 'event_gdg_2026',
      );
      expect(firstResult.isSuccess, isTrue);

      // Unlock for second scan
      viewModel.unlockScanner();

      // Second check-in with the same QR: Rejected with duplicate warning
      final secondResult = await viewModel.processBarcode(
        validPayload,
        expectedEventId: 'event_gdg_2026',
      );

      expect(secondResult.isSuccess, isFalse);
      expect(secondResult.errorCode, 'duplicate_checkin');
      expect(secondResult.message, contains('Quét trùng'));
    });

    test('rejects check-in for cancelled registrations', () async {
      // Mark registration as cancelled
      await fakeFirestore
          .collection('registrations')
          .doc(testRegistration.id)
          .update({'status': RegistrationStatus.cancelled.name});

      final viewModel = container.read(checkinViewModelProvider.notifier);

      final payload = const QrPayload(
        version: 1,
        registrationId: 'event_gdg_2026_student_attendee_01',
        eventId: 'event_gdg_2026',
        token: 'valid-qr-uuid-secret-token',
      ).encode();

      final result = await viewModel.processBarcode(
        payload,
        expectedEventId: 'event_gdg_2026',
      );

      expect(result.isSuccess, isFalse);
      expect(result.message, contains('không ở trạng thái hoạt động'));
    });

    test('scanner lock prevents concurrent barcode processing until unlocked', () async {
      final viewModel = container.read(checkinViewModelProvider.notifier);

      final payload = const QrPayload(
        version: 1,
        registrationId: 'event_gdg_2026_student_attendee_01',
        eventId: 'event_gdg_2026',
        token: 'valid-qr-uuid-secret-token',
      ).encode();

      // Trigger first scan
      await viewModel.processBarcode(payload, expectedEventId: 'event_gdg_2026');
      expect(container.read(checkinViewModelProvider).isLocked, isTrue);

      // Trigger second scan while locked without unlocking
      final lockedResult = await viewModel.processBarcode(
        payload,
        expectedEventId: 'event_gdg_2026',
      );
      // Returns last result while locked
      expect(lockedResult.isSuccess, isTrue);

      // Explicit unlock restores idle state
      viewModel.unlockScanner();
      expect(container.read(checkinViewModelProvider).isLocked, isFalse);
      expect(container.read(checkinViewModelProvider).status, CheckinStatus.idle);
    });
  });
}

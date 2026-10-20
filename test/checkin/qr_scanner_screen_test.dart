import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/checkin/presentation/screens/qr_scanner_screen.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  final organizerUser = AppUser(
    uid: 'host_organizer_99',
    email: 'organizer@fpt.edu.vn',
    displayName: 'Thái Organizer',
    role: UserRole.organizer,
    status: 'active',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  final studentAttendee = AppUser(
    uid: 'attendee_01',
    email: 'student@fpt.edu.vn',
    displayName: 'Lê Văn B',
    role: UserRole.student,
    status: 'active',
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();

    await fakeFirestore
        .collection('users')
        .doc(organizerUser.uid)
        .set(organizerUser.toMap());
    await fakeFirestore
        .collection('users')
        .doc(studentAttendee.uid)
        .set(studentAttendee.toMap());

    final event = EventModel(
      id: 'event_summit_2026',
      organizerId: organizerUser.uid,
      title: 'AI Summit 2026',
      description: 'Annual Artificial Intelligence gathering.',
      category: 'technology',
      locationName: 'Main Stage',
      startAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
      endAt: DateTime.now().toUtc().add(const Duration(hours: 6)),
      capacity: 500,
      registeredCount: 1,
      checkedInCount: 0,
      status: EventStatus.published,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    await fakeFirestore.collection('events').doc(event.id).set(event.toMap());

    final registration = RegistrationModel(
      id: 'event_summit_2026_attendee_01',
      eventId: 'event_summit_2026',
      userId: studentAttendee.uid,
      status: RegistrationStatus.registered,
      qrToken: 'summit-secret-token-123',
      registeredAt: DateTime.now().toUtc(),
    );
    await fakeFirestore
        .collection('registrations')
        .doc(registration.id)
        .set(registration.toMap());
  });

  group('UC-056: QrScannerScreen Widget Tests', () {
    testWidgets('renders scanner screen with event title and manual entry button', (tester) async {
      final repo = RegistrationRepositoryImpl(
        fakeFirestore,
        null,
        () async => organizerUser,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            registrationRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(AsyncData(organizerUser)),
          ],
          child: const MaterialApp(
            home: QrScannerScreen(
              eventId: 'event_summit_2026',
              eventTitle: 'AI Summit 2026',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Summit 2026'), findsWidgets);
      expect(find.byKey(const Key('manualInputIconButton')), findsOneWidget);
    });

    testWidgets('manual input dialog triggers check-in and opens result screen', (tester) async {
      final repo = RegistrationRepositoryImpl(
        fakeFirestore,
        null,
        () async => organizerUser,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(fakeFirestore),
            registrationRepositoryProvider.overrideWithValue(repo),
            currentUserProvider.overrideWithValue(AsyncData(organizerUser)),
          ],
          child: const MaterialApp(
            home: QrScannerScreen(
              eventId: 'event_summit_2026',
              eventTitle: 'AI Summit 2026',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap manual entry icon button
      await tester.tap(find.byKey(const Key('manualInputIconButton')));
      await tester.pumpAndSettle();

      expect(find.text('Nhập Mã Vé Thủ Công'), findsOneWidget);

      final validPayload = const QrPayload(
        version: 1,
        registrationId: 'event_summit_2026_attendee_01',
        eventId: 'event_summit_2026',
        token: 'summit-secret-token-123',
      ).encode();

      await tester.enterText(
        find.byKey(const Key('manualQrInputField')),
        validPayload,
      );
      await tester.pumpAndSettle();

      // Submit manual check-in
      await tester.tap(find.byKey(const Key('submitManualQrButton')));
      await tester.pumpAndSettle();

      // Check-in result screen opens with success
      expect(find.text('Check-in Thành Công!'), findsOneWidget);
      expect(find.text('Lê Văn B'), findsOneWidget);

      // Tap close returns to scanner screen
      final closeButtonFinder = find.byKey(const Key('checkinResultCloseButton'));
      await tester.ensureVisible(closeButtonFinder);
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('AI Summit 2026'), findsWidgets);
    });
  });
}

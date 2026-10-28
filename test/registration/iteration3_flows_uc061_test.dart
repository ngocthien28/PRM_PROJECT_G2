import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/utils/qr_payload.dart';
import 'package:campushub/features/checkin/presentation/screens/checkin_result_screen.dart';
import 'package:campushub/features/checkin/presentation/viewmodels/checkin_view_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/features/registration/presentation/screens/ticket_screen.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../events/event_fakes.dart';
import 'registration_fakes.dart';

void main() {
  for (final status in EventStatus.values) {
    test(
      'UC-061 canJoin: $status rejects unavailable events without counter changes',
      () async {
        final db = FakeFirebaseFirestore();
        final event = testEvent(status: status, registeredCount: 0);
        await db.collection('events').doc(event.id).set(event.toMap());
        final repo = RegistrationRepositoryImpl(db);
        if (status == EventStatus.published) {
          await repo.joinEvent(eventId: event.id, userId: 'student');
          expect(
            (await db.collection('events').doc(event.id).get())
                .data()!['registeredCount'],
            1,
          );
        } else {
          await expectLater(
            repo.joinEvent(eventId: event.id, userId: 'student'),
            throwsA(isA<AppException>()),
          );
          expect((await db.collection('registrations').get()).docs, isEmpty);
          expect(
            (await db.collection('events').doc(event.id).get())
                .data()!['registeredCount'],
            0,
          );
        }
      },
    );
  }

  test(
    'UC-061 last seat, cancel and rejoin rotate token and reject old QR',
    () async {
      final db = FakeFirebaseFirestore();
      final event = testEvent(capacity: 1, registeredCount: 0);
      await db.collection('events').doc(event.id).set(event.toMap());
      await db.collection('users').doc(event.organizerId).set({
        'role': 'organizer',
        'status': 'active',
      });
      final repo = RegistrationRepositoryImpl(db);
      final first = await repo.joinEvent(eventId: event.id, userId: 'student');
      await expectLater(
        repo.joinEvent(eventId: event.id, userId: 'second'),
        throwsA(isA<AppException>()),
      );
      await repo.cancelRegistration(
        registrationId: first.id,
        userId: first.userId,
      );
      final rejoined = await repo.joinEvent(
        eventId: event.id,
        userId: first.userId,
      );
      expect(rejoined.qrToken, isNot(first.qrToken));
      await expectLater(
        repo.checkIn(organizerId: event.organizerId, payload: first.payload),
        throwsA(isA<AppException>()),
      );
      final result = await repo.checkIn(
        organizerId: event.organizerId,
        payload: rejoined.payload,
      );
      expect(result.isCheckedIn, isTrue);
      await expectLater(
        repo.checkIn(organizerId: event.organizerId, payload: rejoined.payload),
        throwsA(isA<AppException>()),
      );
      final counters = (await db.collection('events').doc(event.id).get())
          .data()!;
      expect(counters['registeredCount'], 1);
      expect(counters['checkedInCount'], 1);
    },
  );

  for (final raw in [
    'not-json',
    '[]',
    '{}',
    '{"rid":12}',
    '{"rid":"r","eid":"e","t":""}',
  ]) {
    test('UC-061 malformed QR is rejected: $raw', () {
      expect(() => QrPayload.decode(raw), throwsA(isA<AppException>()));
    });
  }

  testWidgets('UC-061 ticket renders QR with a valid issued payload', (
    tester,
  ) async {
    final source = testRegistration();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TicketScreen(
            registrationId: source.id,
            initialRegistration: source,
            initialEvent: testEvent(),
          ),
        ),
      ),
    );
    expect(find.byType(QrImageView), findsOneWidget);
    expect(QrPayload.decode(source.encodedQr), source.payload);
  });

  for (final code in [
    'duplicate_checkin',
    'wrong_event',
    'invalid_qr',
    'permission_denied',
    'inactive_account',
    'checkin_failed',
  ]) {
    testWidgets('UC-061 $code result supports retry without showing success', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CheckinResultScreen(
            result: CheckinResult(
              isSuccess: false,
              message: 'Failure: $code',
              errorCode: code,
            ),
            onScanNext: () => retries++,
          ),
        ),
      );
      expect(find.text('Failure: $code'), findsWidgets);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      final retry = find.byKey(const Key('checkinResultScanNextButton'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('UC-061 cancelled ticket has no cancel action', (tester) async {
    final reg = testRegistration(status: RegistrationStatus.cancelled);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TicketScreen(
            registrationId: reg.id,
            initialRegistration: reg,
            initialEvent: testEvent(),
          ),
        ),
      ),
    );
    expect(find.text('Hủy vé đăng ký'), findsNothing);
    expect(find.text('Đã hủy'), findsOneWidget);
  });
}

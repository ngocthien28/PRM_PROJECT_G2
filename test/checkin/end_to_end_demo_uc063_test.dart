import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/checkin/presentation/screens/qr_scanner_screen.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/features/registration/presentation/screens/my_events_screen.dart';
import 'package:campushub/features/registration/presentation/screens/ticket_screen.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import '../registration/participant_integration_uc062_test.dart'
    show MemoryTickets;

void main() {
  for (var run = 1; run <= 3; run++) {
    testWidgets(
      'UC-063 demo $run: Join -> QR -> scanner -> duplicate -> My Events',
      (tester) async {
        final db = FakeFirebaseFirestore();
        final event = testEvent(id: 'demo-$run', registeredCount: 0);
        final student = testUser();
        final owner = testUser(
          uid: event.organizerId,
          role: UserRole.organizer,
        );
        var actor = student;
        final cache = MemoryTickets();
        final repo = RegistrationRepositoryImpl(db, cache, () async => actor);
        await db.collection('events').doc(event.id).set(event.toMap());
        await db.collection('users').doc(student.uid).set(student.toMap());
        await db.collection('users').doc(owner.uid).set(owner.toMap());
        final ticket = await repo.joinEvent(
          eventId: event.id,
          userId: student.uid,
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: TicketScreen(
                registrationId: ticket.id,
                initialRegistration: ticket,
                initialEvent: event,
              ),
            ),
          ),
        );
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('Đã đăng ký'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        actor = owner;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              firestoreProvider.overrideWithValue(db),
              currentUserProvider.overrideWithValue(AsyncData(owner)),
              authStateProvider.overrideWithValue(const AsyncData(null)),
              registrationRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: QrScannerScreen(eventId: event.id, eventTitle: event.title),
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> scan() async {
          await tester.tap(find.byKey(const Key('manualInputIconButton')));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const Key('manualQrInputField')),
            ticket.encodedQr,
          );
          await tester.tap(find.byKey(const Key('submitManualQrButton')));
          await tester.pumpAndSettle();
        }

        await scan();
        expect(find.text('Check-in Thành Công!'), findsOneWidget);
        final next = find.byKey(const Key('checkinResultScanNextButton'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        await scan();
        expect(find.text('Vé Đã Quét Trùng'), findsOneWidget);
        final counters = (await db.collection('events').doc(event.id).get())
            .data()!;
        expect(counters['registeredCount'], 1);
        expect(counters['checkedInCount'], 1);

        await tester.pumpWidget(const SizedBox.shrink());
        actor = student;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authStateProvider.overrideWithValue(
                const AsyncData(testIdentity),
              ),
              currentUserProvider.overrideWithValue(AsyncData(student)),
              unreadNotificationCountProvider.overrideWithValue(0),
              registrationRepositoryProvider.overrideWithValue(repo),
              eventRepositoryProvider.overrideWithValue(
                EventRepositoryImpl(firestore: db),
              ),
            ],
            child: const MaterialApp(home: MyEventsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(Tab, 'Đã check-in'));
        await tester.pumpAndSettle();
        expect(find.text(event.title), findsOneWidget);
        expect(
          (await cache.getTicket(ticket.id))!.toRegistrationModel().isCheckedIn,
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/checkin/presentation/viewmodels/checkin_view_model.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/participant_summary_view_model.dart';
import 'package:campushub/features/registration/data/models/registration_model.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/features/registration/presentation/screens/ticket_screen.dart';
import 'package:campushub/features/registration/presentation/viewmodels/registration_view_model.dart';
import 'package:campushub/local/dao/ticket_dao.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';
import 'registration_fakes.dart';

class MemoryTickets extends TicketDao {
  final records = <String, OfflineTicketRecord>{};
  @override
  Future<void> saveTicket({
    required RegistrationModel registration,
    required String eventTitle,
    required DateTime startAt,
  }) async {
    records[registration.id] = OfflineTicketRecord(
      registrationId: registration.id,
      userId: registration.userId,
      eventId: registration.eventId,
      qrToken: registration.qrToken,
      eventTitle: eventTitle,
      startAt: startAt,
      updatedAt: DateTime.now(),
      status: registration.status,
      registeredAt: registration.registeredAt,
      checkedInAt: registration.checkedInAt,
      cancelledAt: registration.cancelledAt,
    );
  }

  @override
  Future<OfflineTicketRecord?> getTicket(String id) async => records[id];
  @override
  Future<List<OfflineTicketRecord>> getMyTickets(String uid) async =>
      records.values.where((r) => r.userId == uid).toList();
  @override
  Future<void> deleteTicket(String id) async => records.remove(id);
}

void main() {
  test(
    'UC-062 join action -> participant summary -> check-in -> student refresh',
    () async {
      final db = FakeFirebaseFirestore();
      final event = testEvent(registeredCount: 0);
      final owner = testUser(uid: event.organizerId, role: UserRole.organizer);
      final student = testUser();
      await db.collection('events').doc(event.id).set(event.toMap());
      await db.collection('users').doc(owner.uid).set(owner.toMap());
      await db.collection('users').doc(student.uid).set(student.toMap());
      final cache = MemoryTickets();
      final studentRepo = RegistrationRepositoryImpl(
        db,
        cache,
        () async => student,
      );
      final studentScope = ProviderContainer(
        overrides: [
          authStateProvider.overrideWithValue(const AsyncData(testIdentity)),
          currentUserProvider.overrideWithValue(AsyncData(student)),
          registrationRepositoryProvider.overrideWithValue(studentRepo),
          ticketDaoProvider.overrideWithValue(cache),
        ],
      );
      addTearDown(studentScope.dispose);
      await studentScope.read(authStateProvider.future);
      expect(await studentScope.read(myRegistrationsProvider.future), isEmpty);
      final ticket = await studentScope
          .read(registrationActionProvider.notifier)
          .joinEvent(event);
      await studentScope.pump();
      expect(
        (await studentScope.read(myRegistrationsProvider.future)).single.id,
        ticket.id,
      );
      expect(
        (await studentScope.read(
          eventRegistrationStatusProvider(event.id).future,
        ))!.id,
        ticket.id,
      );
      final ownerScope = ProviderContainer(
        overrides: [
          authStateProvider.overrideWithValue(const AsyncData(null)),
          currentUserProvider.overrideWithValue(AsyncData(owner)),
          firestoreProvider.overrideWithValue(db),
          registrationRepositoryProvider.overrideWithValue(
            RegistrationRepositoryImpl(db, null, () async => owner),
          ),
          eventRepositoryProvider.overrideWithValue(
            EventRepositoryImpl(firestore: db),
          ),
        ],
      );
      addTearDown(ownerScope.dispose);
      final subscription = ownerScope.listen(
        participantSummaryProvider(event.id),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final before = await ownerScope.read(
        participantSummaryProvider(event.id).future,
      );
      expect(before.registeredCount, 1);
      expect(before.checkedInCount, 0);
      final scanner = ownerScope.read(checkinViewModelProvider.notifier);
      final success = await scanner.processBarcode(
        ticket.encodedQr,
        expectedEventId: event.id,
      );
      await ownerScope.pump();
      expect(success.isSuccess, isTrue);
      final after = await ownerScope.read(
        participantSummaryProvider(event.id).future,
      );
      expect(after.checkedInCount, 1);
      expect(after.participants.single.isCheckedIn, isTrue);
      expect(after.attendanceRate, 100);
      scanner.unlockScanner();
      expect(ownerScope.read(checkinViewModelProvider).result, isNull);
      final duplicate = await scanner.processBarcode(
        ticket.encodedQr,
        expectedEventId: event.id,
      );
      expect(duplicate.errorCode, 'duplicate_checkin');
      await studentScope.read(myRegistrationsProvider.notifier).refresh();
      expect(
        studentScope
            .read(myRegistrationsProvider)
            .requireValue
            .single
            .isCheckedIn,
        isTrue,
      );
      expect(
        (await cache.getTicket(ticket.id))!.status,
        RegistrationStatus.checkedIn,
      );
      expect(
        (await db.collection('events').doc(event.id).get())
            .data()!['checkedInCount'],
        1,
      );
    },
  );

  testWidgets(
    'UC-062 ticket refresh replaces an old registration with checked-in status',
    (tester) async {
      final old = testRegistration(userId: testIdentity.uid);
      final repo = FakeRegistrationRepository([
        old.copyWith(
          status: RegistrationStatus.checkedIn,
          checkedInAt: DateTime.utc(2030),
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWithValue(const AsyncData(testIdentity)),
            registrationRepositoryProvider.overrideWithValue(repo),
            ticketDaoProvider.overrideWithValue(MemoryTickets()),
          ],
          child: MaterialApp(
            home: TicketScreen(
              registrationId: old.id,
              initialRegistration: old,
              initialEvent: testEvent(),
            ),
          ),
        ),
      );
      expect(find.text('Đã đăng ký'), findsOneWidget);
      await tester.tap(find.byKey(const Key('refreshTicket')));
      await tester.pumpAndSettle();
      expect(find.text('Đã check-in'), findsOneWidget);
      expect(find.text('Hủy vé đăng ký'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

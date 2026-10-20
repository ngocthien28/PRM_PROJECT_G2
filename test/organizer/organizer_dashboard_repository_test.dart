import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

void main() {
  final now = DateTime.utc(2030, 5, 1);
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late FakeFirebaseFirestore db;
  late EventRepositoryImpl repository;
  AppUser? actual;
  setUp(() {
    db = FakeFirebaseFirestore();
    actual = owner;
    repository = EventRepositoryImpl(
      firestore: db,
      authenticatedActor: () async => actual,
    );
  });

  test(
    'dashboard reads beyond the managed-list limit with tied start timestamps',
    () async {
      for (var i = 0; i < 205; i++) {
        final event = testEvent(
          id: 'own-$i',
          registeredCount: 3,
          checkedInCount: 1,
          status: i.isEven ? EventStatus.published : EventStatus.cancelled,
        );
        await db.collection('events').doc(event.id).set(event.toMap());
      }
      await db
          .collection('events')
          .doc('foreign')
          .set(testEvent(id: 'foreign', organizerId: 'other').toMap());
      final before = db.dump();
      expect((await repository.getManagedEvents(actor: owner)).length, 100);
      final summary = await repository.getOrganizerDashboard(
        actor: owner,
        asOf: now,
      );
      expect(summary.totalEvents, 205);
      expect(summary.upcomingCount, 103);
      expect(summary.cancelledCount, 102);
      expect(summary.totalRegistrations, 615);
      expect(summary.totalCheckedIn, 205);
      expect(summary.upcomingEvents.length, 5);
      expect(
        summary.upcomingEvents.every((e) => e.organizerId == owner.uid),
        isTrue,
      );
      expect(
        db.dump(),
        before,
        reason: 'Dashboard must never repair/write data.',
      );
    },
  );

  test(
    'admin organizer dashboard remains personal; management keeps its admin policy',
    () async {
      actual = testUser(uid: 'admin', role: UserRole.admin);
      await db.collection('events').doc('other').set(testEvent().toMap());
      await db
          .collection('events')
          .doc('mine')
          .set(testEvent(id: 'mine', organizerId: 'admin').toMap());
      final summary = await repository.getOrganizerDashboard(
        actor: actual!,
        asOf: now,
      );
      expect(summary.totalEvents, 1);
      expect(summary.upcomingEvents.single.id, 'mine');
      expect((await repository.getManagedEvents(actor: actual!)).length, 2);
    },
  );

  test(
    'stale, disabled, student or forged actors cannot load dashboard',
    () async {
      for (final value in <AppUser?>[
        null,
        testUser(uid: 'someone', role: UserRole.organizer),
        testUser(uid: owner.uid),
        testUser(uid: owner.uid, role: UserRole.organizer, status: 'disabled'),
      ]) {
        actual = value;
        await expectLater(
          repository.getOrganizerDashboard(actor: owner, asOf: now),
          throwsA(isA<AppException>()),
        );
      }
    },
  );

  test(
    'empty data is a real zero summary; repository/auth failures remain errors',
    () async {
      expect(
        (await repository.getOrganizerDashboard(
          actor: owner,
          asOf: now,
        )).totalEvents,
        0,
      );
      final failing = EventRepositoryImpl(
        firestore: db,
        authenticatedActor: () async => throw const AppException(
          'Server unavailable.',
          code: 'unavailable',
        ),
      );
      await expectLater(
        failing.getOrganizerDashboard(actor: owner, asOf: now),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('a later read reflects updated registrations and check-ins', () async {
    await db
        .collection('events')
        .doc('one')
        .set(testEvent(id: 'one', registeredCount: 0).toMap());
    expect(
      (await repository.getOrganizerDashboard(
        actor: owner,
        asOf: now,
      )).totalRegistrations,
      0,
    );
    await db.collection('events').doc('one').update({
      'registeredCount': 8,
      'checkedInCount': 3,
    });
    final summary = await repository.getOrganizerDashboard(
      actor: owner,
      asOf: now,
    );
    expect(summary.totalRegistrations, 8);
    expect(summary.totalCheckedIn, 3);
  });
}

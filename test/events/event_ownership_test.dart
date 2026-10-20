import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import '../auth/auth_fakes.dart';
import 'event_fakes.dart';

void main() {
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  final now = DateTime.utc(2030, 1, 1);
  final input = EventFormInput(
    title: 'Ownership workshop',
    description: 'A valid campus workshop with practical exercises.',
    category: 'technology',
    locationName: 'Hall A',
    startAt: now.add(const Duration(days: 1)),
    endAt: now.add(const Duration(days: 1, hours: 2)),
    capacity: 100,
  );
  late FakeFirebaseFirestore db;
  late EventRepositoryImpl repository;
  AppUser? actual;
  setUp(() async {
    actual = owner;
    db = FakeFirebaseFirestore();
    repository = EventRepositoryImpl(
      firestore: db,
      now: () => now,
      authenticatedActor: () async => actual,
    );
    await db
        .collection('events')
        .doc('event-1')
        .set(testEvent(registeredCount: 3, checkedInCount: 1).toMap());
    await db.collection('registrations').doc('history').set({
      'eventId': 'event-1',
    });
  });
  Future<void> deniedMutations(AppUser supplied, String error) async {
    final before = db.dump();
    for (final operation in [
      () => repository.createEvent(input: input, actor: supplied),
      () => repository.updateEvent(
        eventId: 'event-1',
        input: input,
        actor: supplied,
      ),
      () => repository.cancelEvent(eventId: 'event-1', actor: supplied),
    ]) {
      await expectLater(
        operation(),
        throwsA(isA<AppException>().having((e) => e.code, 'code', error)),
      );
      expect(db.dump(), before);
    }
  }

  test(
    'Student cannot create/update/cancel even with a forged admin actor role',
    () async {
      actual = testUser(uid: owner.uid);
      await deniedMutations(
        testUser(uid: owner.uid, role: UserRole.admin),
        'event-forbidden',
      );
    },
  );
  test(
    'guest or mismatched authenticated identity cannot impersonate an organizer',
    () async {
      actual = null;
      await deniedMutations(owner, 'unauthenticated');
      actual = testUser(uid: 'other', role: UserRole.organizer);
      await deniedMutations(owner, 'unauthenticated');
    },
  );
  test('fresh disabled profile defeats a stale active actor', () async {
    actual = testUser(
      uid: owner.uid,
      role: UserRole.organizer,
      status: 'disabled',
    );
    await deniedMutations(owner, 'event-forbidden');
  });
  test(
    'non-owner update/cancel denied using current transaction ownership',
    () async {
      actual = testUser(uid: 'other', role: UserRole.organizer);
      for (final action in [
        () => repository.updateEvent(
          eventId: 'event-1',
          input: input,
          actor: actual!,
        ),
        () => repository.cancelEvent(eventId: 'event-1', actor: actual!),
      ]) {
        await expectLater(
          action(),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'event-forbidden',
            ),
          ),
        );
      }
      expect(
        (await db.collection('events').doc('event-1').get()).data()!['status'],
        'published',
      );
    },
  );
  test(
    'owner cancels softly and repeat cancel preserves history and protected data',
    () async {
      final before = (await db.collection('events').doc('event-1').get())
          .data()!;
      final cancelled = await repository.cancelEvent(
        eventId: 'event-1',
        actor: owner,
      );
      expect(cancelled.status, EventStatus.cancelled);
      final again = await repository.cancelEvent(
        eventId: 'event-1',
        actor: owner,
      );
      expect(again.updatedAt, cancelled.updatedAt);
      final after = (await db.collection('events').doc('event-1').get())
          .data()!;
      for (final field in before.keys.where(
        (f) => !{'status', 'updatedAt'}.contains(f),
      )) {
        expect(after[field], before[field]);
      }
      expect(
        (await db.collection('registrations').doc('history').get()).exists,
        isTrue,
      );
    },
  );
  test(
    'admin override preserves owner; admin create uses authenticated admin UID',
    () async {
      actual = testUser(uid: 'admin', role: UserRole.admin);
      final updated = await repository.updateEvent(
        eventId: 'event-1',
        input: input,
        actor: actual!,
      );
      expect(updated.organizerId, owner.uid);
      expect(
        (await repository.cancelEvent(
          eventId: 'event-1',
          actor: actual!,
        )).organizerId,
        owner.uid,
      );
      expect(
        (await repository.createEvent(
          input: input,
          actor: actual!,
        )).organizerId,
        'admin',
      );
    },
  );
}

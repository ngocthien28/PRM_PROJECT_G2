import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import 'event_fakes.dart';

// Simulates a discarded transaction attempt; it deliberately never commits.
// Real Firestore atomicity/OCC still requires an emulator test.
class _DiscardedTransaction extends Fake implements Transaction {
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) => reference.get();
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) =>
      this;
}

class _ControlledFirestore extends FakeFirebaseFirestore {
  Object? transactionFailure;
  Future<void>? gate;
  Future<void> Function()? betweenAttempts;
  int attempts = 0;

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (gate != null) await gate;
    if (transactionFailure != null) throw transactionFailure!;
    if (betweenAttempts != null) {
      attempts++;
      await handler(_DiscardedTransaction());
      await betweenAttempts!();
    }
    attempts++;
    return super.runTransaction(
      handler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
  }
}

void main() {
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  final now = DateTime.utc(2030, 1, 1);
  late _ControlledFirestore db;
  late EventRepositoryImpl repository;
  EventFormInput input({String title = 'Updated event', int capacity = 100}) =>
      EventFormInput(
        title: title,
        description: 'Updated details for a practical campus workshop.',
        category: 'music',
        locationName: ' Hall B ',
        startAt: now.subtract(const Duration(hours: 1)),
        endAt: now.add(const Duration(hours: 1)),
        capacity: capacity,
      );
  setUp(() async {
    db = _ControlledFirestore();
    repository = EventRepositoryImpl(firestore: db, now: () => now);
    await db.collection('events').doc('event-1').set({
      ...testEvent(
        registeredCount: 20,
        checkedInCount: 3,
        posterUrl: 'https://example.invalid/poster.png',
      ).toMap(),
      'customMetadata': 'preserve-other-members',
      'createdAt': Timestamp.fromDate(DateTime.utc(2025)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2025)),
    });
  });
  Matcher code(String value) =>
      isA<AppException>().having((e) => e.code, 'code', value);

  test(
    'manager read loads drafts without weakening published-only Student reads',
    () async {
      await db.collection('events').doc('event-1').update({'status': 'draft'});
      expect(
        (await repository.getEventById('event-1', actor: owner)).status,
        EventStatus.draft,
      );
      await expectLater(
        repository.getEventById('event-1'),
        throwsA(code('event-not-found')),
      );
      await expectLater(
        repository.getEventById('event-1', actor: testUser()),
        throwsA(code('event-forbidden')),
      );
      await expectLater(
        repository.getEventById(
          'event-1',
          actor: testUser(uid: 'other', role: UserRole.organizer),
        ),
        throwsA(code('event-not-found')),
      );
      expect(
        (await repository.getEventById(
          'event-1',
          actor: testUser(role: UserRole.admin),
        )).id,
        'event-1',
      );
    },
  );

  test(
    'partial transaction update preserves all protected fields and metadata',
    () async {
      final before = (await db.collection('events').doc('event-1').get())
          .data()!;
      final original = await repository.getEventById('event-1', actor: owner);
      final event = await repository.updateEvent(
        eventId: original.id,
        input: input(),
        actor: owner,
        expectedUpdatedAt: original.updatedAt,
      );
      final after = (await db.collection('events').doc('event-1').get())
          .data()!;
      for (final field in [
        'organizerId',
        'registeredCount',
        'checkedInCount',
        'createdAt',
        'posterUrl',
        'clubId',
        'latitude',
        'longitude',
        'status',
        'customMetadata',
      ]) {
        expect(after[field], before[field], reason: field);
      }
      expect(event.title, 'Updated event');
      expect(event.locationName, 'Hall B');
      expect(event.category, 'music');
      expect(event.updatedAt.isAfter(original.updatedAt), isTrue);
      expect((await repository.getEventById(event.id)).title, 'Updated event');
    },
  );

  test('capacity uses latest registrations at write time', () async {
    await db.collection('events').doc('event-1').update({
      'registeredCount': 70,
    });
    await expectLater(
      repository.updateEvent(
        eventId: 'event-1',
        input: input(capacity: 69),
        actor: owner,
      ),
      throwsA(code('event-capacity-below-registered')),
    );
    expect(
      (await db.collection('events').doc('event-1').get()).data()!['capacity'],
      100,
    );
    final updated = await repository.updateEvent(
      eventId: 'event-1',
      input: input(capacity: 70),
      actor: owner,
    );
    expect(updated.capacity, 70);
    expect(updated.registeredCount, 70);
  });

  test('stale form cannot overwrite a newer edit', () async {
    final original = await repository.getEventById('event-1', actor: owner);
    await db.collection('events').doc('event-1').update({
      'title': 'Newer server edit',
      'updatedAt': Timestamp.fromDate(now),
    });
    await expectLater(
      repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
        expectedUpdatedAt: original.updatedAt,
      ),
      throwsA(code('event-edit-conflict')),
    );
    expect(
      (await repository.getEventById('event-1')).title,
      'Newer server edit',
    );
  });

  test(
    'owner/admin allowed; Student, non-owner and inactive actors denied',
    () async {
      for (final actor in [
        testUser(),
        testUser(uid: 'other', role: UserRole.organizer),
        testUser(uid: owner.uid, role: UserRole.organizer, status: 'disabled'),
      ]) {
        await expectLater(
          repository.updateEvent(
            eventId: 'event-1',
            input: input(),
            actor: actor,
          ),
          throwsA(code('event-forbidden')),
        );
      }
      expect(
        (await repository.getEventById('event-1')).title,
        'Flutter Workshop',
      );
      final event = await repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: testUser(role: UserRole.admin),
      );
      expect(event.organizerId, owner.uid);
    },
  );

  test('cancel or deletion while editing is checked again on save', () async {
    final original = await repository.getEventById('event-1', actor: owner);
    await db.collection('events').doc('event-1').update({
      'status': 'cancelled',
    });
    await expectLater(
      repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
        expectedUpdatedAt: original.updatedAt,
      ),
      throwsA(code('event-cancelled')),
    );
    await db.collection('events').doc('event-1').delete();
    await expectLater(
      repository.updateEvent(eventId: 'event-1', input: input(), actor: owner),
      throwsA(code('event-not-found')),
    );
  });

  test('invalid ID and invalid form do not mutate the document', () async {
    for (final id in ['', 'bad/path', 'missing']) {
      await expectLater(
        repository.getEventById(id, actor: owner),
        throwsA(code('event-not-found')),
      );
      await expectLater(
        repository.updateEvent(eventId: id, input: input(), actor: owner),
        throwsA(code('event-not-found')),
      );
    }
    await expectLater(
      repository.updateEvent(
        eventId: 'event-1',
        input: input(title: ' '),
        actor: owner,
      ),
      throwsA(code('invalid-event-input')),
    );
    expect(
      (await repository.getEventById('event-1')).title,
      'Flutter Workshop',
    );
  });

  test('transaction retry rechecks a concurrently increased counter', () async {
    db.betweenAttempts = () =>
        db.collection('events').doc('event-1').update({'registeredCount': 70});
    await expectLater(
      repository.updateEvent(
        eventId: 'event-1',
        input: input(capacity: 50),
        actor: owner,
      ),
      throwsA(code('event-capacity-below-registered')),
    );
    expect(db.attempts, 2);
    final persisted = await repository.getEventById('event-1');
    expect(persisted.title, 'Flutter Workshop');
    expect(persisted.registeredCount, 70);
    expect(persisted.capacity, 100);
  });

  test(
    'transaction retry preserves a concurrent registration when capacity remains valid',
    () async {
      db.betweenAttempts = () => db.collection('events').doc('event-1').update({
        'registeredCount': 25,
        'checkedInCount': 4,
      });
      final updated = await repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
      );
      expect(updated.registeredCount, 25);
      expect(updated.checkedInCount, 4);
      expect(updated.title, 'Updated event');
    },
  );

  test(
    'permission and unavailable errors are mapped without mutation',
    () async {
      for (final failure in ['permission-denied', 'unavailable']) {
        db.transactionFailure = FirebaseException(
          plugin: 'cloud_firestore',
          code: failure,
        );
        await expectLater(
          repository.updateEvent(
            eventId: 'event-1',
            input: input(),
            actor: owner,
          ),
          throwsA(code(failure)),
        );
      }
      expect(
        (await repository.getEventById('event-1')).title,
        'Flutter Workshop',
      );
    },
  );

  test(
    'pending transaction has a bounded timeout and never reports success',
    () async {
      final gate = Completer<void>();
      db.gate = gate.future;
      db.transactionFailure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      repository = EventRepositoryImpl(
        firestore: db,
        requestTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(),
          actor: owner,
        ),
        throwsA(code('event-timeout')),
      );
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(
        (await db.collection('events').doc('event-1').get()).data()!['title'],
        'Flutter Workshop',
      );
    },
  );
}

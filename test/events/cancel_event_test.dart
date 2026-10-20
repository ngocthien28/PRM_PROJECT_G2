import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import 'event_fakes.dart';

class _ObservedTransaction extends Fake implements Transaction {
  _ObservedTransaction(this.delegate, this.writes, this.commits);
  final Transaction delegate;
  final List<Map<Object, Object?>> writes;
  final List<Future<void>> commits;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) => delegate.get(reference);
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) {
    writes.add(Map.of(data));
    // FakeFirestore's dummy transaction does not await its writes. Await these
    // explicitly in the harness to model a committed server acknowledgement.
    commits.add(reference.update(data));
    return this;
  }

  @override
  Transaction delete(DocumentReference reference) =>
      throw StateError('Hard delete is forbidden.');
}

class _DiscardedTransaction extends Fake implements Transaction {
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) => reference.get();
  @override
  Transaction update(DocumentReference reference, Map<Object, Object?> data) =>
      this;
}

class _CancelFirestore extends FakeFirebaseFirestore {
  int requests = 0;
  final writes = <Map<Object, Object?>>[];
  Future<void>? gate;
  Object? failure;
  bool loseAcknowledgement = false;
  Future<void> Function()? beforeRetry;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    requests++;
    if (gate != null) await gate;
    if (failure != null) throw failure!;
    if (beforeRetry != null) {
      await handler(_DiscardedTransaction());
      await beforeRetry!();
    }
    final commits = <Future<void>>[];
    final result = await super.runTransaction(
      (tx) => handler(_ObservedTransaction(tx, writes, commits)),
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
    await Future.wait(commits);
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return result;
  }
}

void main() {
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late _CancelFirestore db;
  late EventRepositoryImpl repository;
  AppUser? actual;
  setUp(() async {
    actual = owner;
    db = _CancelFirestore();
    repository = EventRepositoryImpl(
      firestore: db,
      authenticatedActor: () async => actual,
    );
    await db.collection('events').doc('event-1').set({
      ...testEvent(
        registeredCount: 3,
        checkedInCount: 1,
        posterUrl: 'https://example.invalid/poster.png',
      ).toMap(),
      'clubId': 'club-1',
      'latitude': 10.0,
      'longitude': 106.0,
      'customMetadata': 'preserve',
      'lastCheckInRegistrationId': 'event-1_s1',
    });
    for (final status in ['registered', 'checkedIn', 'cancelled']) {
      await db.collection('registrations').doc(status).set({
        'eventId': 'event-1',
        'status': status,
        'qrToken': 'keep-token',
      });
    }
  });
  Matcher code(String value) =>
      isA<AppException>().having((e) => e.code, 'code', value);
  Future<void> cancel() =>
      repository.cancelEvent(eventId: 'event-1', actor: owner);

  test(
    'owner soft cancellation writes only status and server timestamp, preserving every other field/registration',
    () async {
      final before = (await db.collection('events').doc('event-1').get())
          .data()!;
      final registrations = await db.collection('registrations').get();
      final result = await repository.cancelEvent(
        eventId: 'event-1',
        actor: owner,
      );
      expect(result.status, EventStatus.cancelled);
      expect(db.writes.single.keys, unorderedEquals(['status', 'updatedAt']));
      expect(db.writes.single['updatedAt'], isA<FieldValue>());
      final after = (await db.collection('events').doc('event-1').get())
          .data()!;
      expect(after['updatedAt'], isA<Timestamp>());
      for (final field in before.keys.where(
        (key) => !{'status', 'updatedAt'}.contains(key),
      )) {
        expect(after[field], before[field], reason: field);
      }
      expect(
        (await db.collection('registrations').get()).docs.map((e) => e.data()),
        registrations.docs.map((e) => e.data()),
      );
    },
  );

  for (final role in [UserRole.student, UserRole.organizer]) {
    test('non-owner $role cannot cancel', () async {
      actual = testUser(uid: 'other', role: role);
      final before = db.dump();
      await expectLater(
        repository.cancelEvent(eventId: 'event-1', actor: actual!),
        throwsA(code('event-forbidden')),
      );
      expect(db.dump(), before);
    });
  }
  test(
    'active admin cancels another owner without changing ownership',
    () async {
      actual = testUser(uid: 'admin', role: UserRole.admin);
      final result = await repository.cancelEvent(
        eventId: 'event-1',
        actor: actual!,
      );
      expect(result.organizerId, owner.uid);
      expect(result.status, EventStatus.cancelled);
    },
  );
  test('fresh identity/role/status defeats forged or stale actor', () async {
    for (final user in <AppUser?>[
      null,
      testUser(uid: 'other', role: UserRole.admin),
      testUser(uid: owner.uid),
      testUser(uid: owner.uid, role: UserRole.organizer, status: 'disabled'),
    ]) {
      actual = user;
      await expectLater(cancel(), throwsA(isA<AppException>()));
    }
    expect(db.writes, isEmpty);
  });
  for (final id in ['', 'a/b', 'missing']) {
    test('invalid or missing event $id is not-found without writes', () async {
      await expectLater(
        repository.cancelEvent(eventId: id, actor: owner),
        throwsA(code('event-not-found')),
      );
      expect(db.writes, isEmpty);
    });
  }
  test(
    'repeat cancellation does not mutate updatedAt or write again',
    () async {
      await cancel();
      final before = db.dump();
      await cancel();
      expect(db.dump(), before);
      expect(db.writes.length, 1);
    },
  );
  test(
    'cancelled event stays in management history but disappears from real repository discovery',
    () async {
      expect(await repository.getUpcomingEvents(), hasLength(1));
      await cancel();
      expect(await repository.getUpcomingEvents(), isEmpty);
      expect(
        (await repository.getManagedEvents(actor: owner)).single.status,
        EventStatus.cancelled,
      );
    },
  );
  for (final status in EventStatus.values.where(
    (e) => e != EventStatus.cancelled,
  )) {
    test(
      'existing policy permits cancellation of $status without a new time restriction',
      () async {
        await db.collection('events').doc('event-1').update({
          'status': status.name,
          'startAt': Timestamp.fromDate(DateTime.utc(2020)),
          'endAt': Timestamp.fromDate(DateTime.utc(2020, 1, 2)),
        });
        await cancel();
        expect(
          (await db.collection('events').doc('event-1').get())
              .data()!['status'],
          'cancelled',
        );
      },
    );
  }
  for (final failure in ['permission-denied', 'unavailable']) {
    test('$failure never reports success and retry is possible', () async {
      final before = db.dump();
      db.failure = FirebaseException(plugin: 'cloud_firestore', code: failure);
      await expectLater(cancel(), throwsA(code(failure)));
      expect(db.dump(), before);
      db.failure = null;
      await cancel();
      expect(db.writes.length, 1);
    });
  }
  test(
    'simultaneous callers share one transaction and wait for acknowledgement',
    () async {
      final gate = Completer<void>();
      db.gate = gate.future;
      var completed = false;
      final first = cancel().then((_) => completed = true);
      final second = cancel();
      await Future<void>.delayed(Duration.zero);
      expect(db.requests, 1);
      expect(completed, isFalse);
      gate.complete();
      await Future.wait([first, second]);
      expect(db.writes.length, 1);
    },
  );
  test(
    'timeout is not success; retry joins an unresolved original transaction',
    () async {
      repository = EventRepositoryImpl(
        firestore: db,
        requestTimeout: const Duration(milliseconds: 20),
      );
      final gate = Completer<void>();
      db.gate = gate.future;
      await expectLater(cancel(), throwsA(code('event-timeout')));
      await expectLater(cancel(), throwsA(code('event-timeout')));
      expect(db.requests, 1);
      expect(db.writes, isEmpty);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cancel();
      expect(db.writes.length, 1);
    },
  );
  test(
    'lost acknowledgement after commit is an error; retry is idempotent',
    () async {
      db.loseAcknowledgement = true;
      await expectLater(cancel(), throwsA(code('unavailable')));
      final afterCommit = db.dump();
      await cancel();
      expect(db.dump(), afterCommit);
      expect(db.writes.length, 1);
    },
  );
  test(
    'transaction retry re-reads concurrent cancellation and does not overwrite it',
    () async {
      final concurrentTime = Timestamp.fromDate(DateTime.utc(2031));
      db.beforeRetry = () => db.collection('events').doc('event-1').update({
        'status': 'cancelled',
        'updatedAt': concurrentTime,
        'registeredCount': 4,
      });
      await cancel();
      expect(db.writes, isEmpty);
      final data = (await db.collection('events').doc('event-1').get()).data()!;
      expect(data['updatedAt'], concurrentTime);
      expect(data['registeredCount'], 4);
    },
  );
}

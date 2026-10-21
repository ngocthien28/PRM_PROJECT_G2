import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../organizer/poster_fixtures.dart';
import 'event_fakes.dart';

class FakePosterService implements EventPosterService {
  int uploads = 0;
  int deletions = 0;
  String? uploadedEvent;
  Object? failure;
  Future<void>? gate;
  UploadedEventPoster uploaded = const UploadedEventPoster(
    path: 'events/event-1/new.png',
    url:
        'https://res.cloudinary.com/djznx3z7o/image/upload/v123/campushub/event_posters/event-1/new.png',
  );
  @override
  Future<UploadedEventPoster> upload(
    String eventId,
    EventPosterSelection image,
  ) async {
    uploads++;
    uploaded = UploadedEventPoster(
      path: 'campushub/event_posters/$eventId/new',
      url:
          'https://res.cloudinary.com/djznx3z7o/image/upload/v123/campushub/event_posters/$eventId/new.png',
    );
    uploadedEvent = eventId;
    if (gate != null) await gate;
    if (failure != null) throw failure!;
    return uploaded;
  }

  @override
  Future<void> delete(UploadedEventPoster poster) async {
    deletions++;
  }
}

class PosterFirestore extends FakeFirebaseFirestore {
  Object? beforeCommitFailure;
  bool loseCommitResponse = false;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    if (beforeCommitFailure != null) throw beforeCommitFailure!;
    final value = await super.runTransaction(
      handler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
    if (loseCommitResponse) {
      loseCommitResponse = false;
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2030);
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late PosterFirestore db;
  late FakePosterService storage;
  late EventRepositoryImpl repository;
  final selected = posterSelection();
  EventFormInput input({
    bool withPoster = true,
    String title = 'Updated workshop',
  }) => EventFormInput(
    title: title,
    description: 'A practical workshop for students on campus.',
    category: 'technology',
    locationName: 'Hall B',
    startAt: now.add(const Duration(days: 1)),
    endAt: now.add(const Duration(days: 1, hours: 2)),
    capacity: 100,
    posterSelection: withPoster ? selected : null,
    createRequestId: 'one-form-request',
  );
  Future<Map<String, dynamic>> saved() async =>
      (await db.collection('events').doc('event-1').get()).data()!;
  setUp(() async {
    db = PosterFirestore();
    storage = FakePosterService();
    repository = EventRepositoryImpl(
      firestore: db,
      posterService: storage,
      now: () => now,
    );
    await db
        .collection('events')
        .doc('event-1')
        .set(
          testEvent(
            registeredCount: 20,
            checkedInCount: 3,
            posterUrl: 'https://example.invalid/old.png',
          ).toMap(),
        );
  });

  test(
    'replaces poster and editable values while preserving protected data',
    () async {
      final before = await saved();
      final updated = await repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
      );
      expect(updated.posterUrl, storage.uploaded.url);
      final after = await saved();
      for (final key in [
        'organizerId',
        'registeredCount',
        'checkedInCount',
        'createdAt',
        'clubId',
        'latitude',
        'longitude',
      ]) {
        expect(after[key], before[key], reason: key);
      }
      expect(after['locationName'], 'Hall B');
      expect(storage.uploadedEvent, 'event-1');
      expect(storage.deletions, 0); // Never delete the previous poster.
    },
  );
  test(
    'editing without selection keeps the old poster and does not upload',
    () async {
      final before = await saved();
      final updated = await repository.updateEvent(
        eventId: 'event-1',
        input: input(withPoster: false),
        actor: owner,
      );
      expect(updated.posterUrl, before['posterUrl']);
      expect(storage.uploads, 0);
    },
  );
  test('upload failure preserves old poster and form can retry', () async {
    storage.failure = const AppException(
      'Network failure',
      code: 'poster-upload-failed',
    );
    await expectLater(
      repository.updateEvent(eventId: 'event-1', input: input(), actor: owner),
      throwsA(isA<AppException>()),
    );
    expect((await saved())['posterUrl'], 'https://example.invalid/old.png');
    storage.failure = null;
    expect(
      (await repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
      )).posterUrl,
      storage.uploaded.url,
    );
  });
  test(
    'definite Firestore denial cleans up new upload and preserves old reference',
    () async {
      db.beforeCommitFailure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(),
          actor: owner,
        ),
        throwsA(isA<AppException>()),
      );
      expect((await saved())['posterUrl'], 'https://example.invalid/old.png');
      expect(storage.deletions, 1);
    },
  );
  test(
    'uncertain commit retains the file and retry confirms without another upload',
    () async {
      db.loseCommitResponse = true;
      final version = testEvent().updatedAt;
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(),
          actor: owner,
          expectedUpdatedAt: version,
        ),
        throwsA(isA<AppException>()),
      );
      expect((await saved())['posterUrl'], storage.uploaded.url);
      final updated = await repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
        expectedUpdatedAt: version,
      );
      expect(updated.posterUrl, storage.uploaded.url);
      expect(storage.uploads, 1);
      expect(storage.deletions, 0);
    },
  );
  test('student, disabled actor and another organizer cannot upload', () async {
    for (final actor in [
      testUser(role: UserRole.student),
      testUser(uid: 'other', role: UserRole.organizer),
      testUser(uid: owner.uid, role: UserRole.organizer, status: 'disabled'),
    ]) {
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(),
          actor: actor,
        ),
        throwsA(isA<AppException>()),
      );
    }
    expect(storage.uploads, 0);
  });
  test('admin can replace another organizers poster', () async {
    final updated = await repository.updateEvent(
      eventId: 'event-1',
      input: input(),
      actor: testUser(uid: 'admin', role: UserRole.admin),
    );
    expect(updated.posterUrl, storage.uploaded.url);
  });
  test('create waits for poster URL before success', () async {
    final event = await repository.createEvent(input: input(), actor: owner);
    expect(event.posterUrl, storage.uploaded.url);
    expect(storage.uploadedEvent, event.id);
    expect(
      (await db.collection('events').doc(event.id).get()).data()!['posterUrl'],
      storage.uploaded.url,
    );
  });
  test(
    'create poster retry reuses same event even when form fields change',
    () async {
      storage.failure = const AppException(
        'Upload failed',
        code: 'poster-upload-failed',
      );
      await expectLater(
        repository.createEvent(input: input(), actor: owner),
        throwsA(isA<AppException>()),
      );
      final createdId = storage.uploadedEvent;
      expect((await db.collection('events').get()).docs, hasLength(2));
      storage.failure = null;
      final event = await repository.createEvent(
        input: input(title: 'Changed while retrying'),
        actor: owner,
      );
      expect(event.id, createdId);
      expect(event.title, 'Changed while retrying');
      expect(event.posterUrl, storage.uploaded.url);
      expect((await db.collection('events').get()).docs, hasLength(2));
    },
  );
  test(
    'overlapping saves share the same upload and transaction result',
    () async {
      final gate = Completer<void>();
      storage.gate = gate.future;
      final first = repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
      );
      final second = repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
      gate.complete();
      await Future.wait([first, second]);
      expect(storage.uploads, 1);
    },
  );
  test(
    'a conflicting retry never deletes a poster attached by an uncertain commit',
    () async {
      db.loseCommitResponse = true;
      final version = testEvent().updatedAt;
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(),
          actor: owner,
          expectedUpdatedAt: version,
        ),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(title: 'Changed after response loss'),
          actor: owner,
          expectedUpdatedAt: version,
        ),
        throwsA(isA<AppException>()),
      );
      expect((await saved())['posterUrl'], storage.uploaded.url);
      expect(storage.deletions, 0);
      expect(storage.uploads, 1);
    },
  );
  test(
    'create timeout followed by late success confirms the same event and upload',
    () async {
      final gate = Completer<void>();
      storage.gate = gate.future;
      repository = EventRepositoryImpl(
        firestore: db,
        posterService: storage,
        now: () => now,
        requestTimeout: const Duration(milliseconds: 150),
      );
      await expectLater(
        repository.createEvent(input: input(), actor: owner),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'event-timeout'),
        ),
      );
      gate.complete();
      await db
          .collection('events')
          .snapshots()
          .firstWhere(
            (snapshot) => snapshot.docs.any(
              (doc) =>
                  doc.id == storage.uploadedEvent &&
                  doc.data()['posterUrl'] == storage.uploaded.url,
            ),
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final event = await repository.createEvent(input: input(), actor: owner);
      expect(event.id, storage.uploadedEvent);
      expect(event.posterUrl, storage.uploaded.url);
      expect(storage.uploads, 1);
      expect((await db.collection('events').get()).docs, hasLength(2));
    },
  );
  test(
    'edit timeout followed by late success confirms without uploading twice',
    () async {
      final gate = Completer<void>();
      storage.gate = gate.future;
      repository = EventRepositoryImpl(
        firestore: db,
        posterService: storage,
        now: () => now,
        requestTimeout: const Duration(milliseconds: 150),
      );
      final version = testEvent().updatedAt;
      await expectLater(
        repository.updateEvent(
          eventId: 'event-1',
          input: input(),
          actor: owner,
          expectedUpdatedAt: version,
        ),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'event-timeout'),
        ),
      );
      gate.complete();
      await db
          .collection('events')
          .doc('event-1')
          .snapshots()
          .firstWhere(
            (doc) => doc.data()?['posterUrl'] == storage.uploaded.url,
          );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final event = await repository.updateEvent(
        eventId: 'event-1',
        input: input(),
        actor: owner,
        expectedUpdatedAt: version,
      );
      expect(event.posterUrl, storage.uploaded.url);
      expect(storage.uploads, 1);
    },
  );
  test('invalid selected file is rejected before creation or upload', () async {
    final invalid = EventFormInput(
      title: 'Invalid poster event',
      description: input().description,
      category: 'technology',
      locationName: 'Hall A',
      startAt: input().startAt,
      endAt: input().endAt,
      capacity: 100,
      posterSelection: EventPosterSelection(localUri: Uri()),
    );
    await expectLater(
      repository.createEvent(input: invalid, actor: owner),
      throwsA(isA<AppException>()),
    );
    expect((await db.collection('events').get()).docs, hasLength(1));
    expect(storage.uploads, 0);
  });
}

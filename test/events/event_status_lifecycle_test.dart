import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../organizer/poster_fixtures.dart';
import 'event_fakes.dart';
import 'event_poster_repository_test.dart'
    show FakePosterService, PosterFirestore;

void main() {
  final now = DateTime.utc(2030);
  final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
  late FakeFirebaseFirestore db;
  late EventRepositoryImpl repository;
  EventFormInput input([EventStatus? status]) => EventFormInput(
    title: 'Campus workshop',
    description: 'Complete workshop information for students on campus.',
    category: 'technology',
    locationName: 'Hall A',
    startAt: now.add(const Duration(days: 1)),
    endAt: now.add(const Duration(days: 1, hours: 2)),
    capacity: 80,
    status: status,
  );
  Matcher code(String value) =>
      isA<AppException>().having((e) => e.code, 'code', value);

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = EventRepositoryImpl(firestore: db, now: () => now);
  });

  test(
    'create persists selected draft status and keeps full validation',
    () async {
      final draft = await repository.createEvent(
        input: input(EventStatus.draft),
        actor: owner,
      );
      expect(draft.status, EventStatus.draft);
      expect(
        (await repository.getManagedEvents(actor: owner)).single.id,
        draft.id,
      );
      await expectLater(
        repository.getEventById(draft.id),
        throwsA(code('event-not-found')),
      );
      await expectLater(
        repository.createEvent(
          input: input(EventStatus.draft).copyWith(description: ''),
          actor: owner,
        ),
        throwsA(code('invalid-event-input')),
      );
      expect((await db.collection('events').get()).docs, hasLength(1));
    },
  );

  test(
    'legacy create remains published and legacy draft edit preserves status',
    () async {
      expect(
        (await repository.createEvent(input: input(), actor: owner)).status,
        EventStatus.published,
      );
      await db
          .collection('events')
          .doc('draft')
          .set(
            testEvent(
              id: 'draft',
              status: EventStatus.draft,
              registeredCount: 0,
              checkedInCount: 0,
            ).toMap(),
          );
      final edited = await repository.updateEvent(
        eventId: 'draft',
        input: input().copyWith(title: 'Edited draft'),
        actor: owner,
      );
      expect(edited.status, EventStatus.draft);
    },
  );

  test(
    'draft edits and publication retain the same ID and protected fields',
    () async {
      final created = await repository.createEvent(
        input: input(EventStatus.draft),
        actor: owner,
      );
      final edited = await repository.updateEvent(
        eventId: created.id,
        input: input(EventStatus.draft).copyWith(title: 'Edited workshop'),
        actor: owner,
        expectedUpdatedAt: created.updatedAt,
      );
      expect(edited.status, EventStatus.draft);
      final published = await repository.updateEvent(
        eventId: created.id,
        input: input(EventStatus.published),
        actor: owner,
        expectedUpdatedAt: edited.updatedAt,
      );
      expect(published.id, created.id);
      expect(published.status, EventStatus.published);
      expect(published.organizerId, created.organizerId);
      expect(published.createdAt, created.createdAt);
      expect(published.registeredCount, 0);
      expect(published.checkedInCount, 0);
      expect(
        (await repository.getEventById(created.id)).status,
        EventStatus.published,
      );
    },
  );

  test(
    'draft may retain past schedule but publication requires future start',
    () async {
      final past = input(EventStatus.draft).copyWith(
        startAt: now.subtract(const Duration(days: 2)),
        endAt: now.subtract(const Duration(days: 1)),
      );
      final draft = await repository.createEvent(input: past, actor: owner);
      await expectLater(
        repository.updateEvent(
          eventId: draft.id,
          input: past.copyWith(status: EventStatus.published),
          actor: owner,
        ),
        throwsA(code('invalid-event-input')),
      );
      expect(
        (await repository.getEventById(draft.id, actor: owner)).status,
        EventStatus.draft,
      );
    },
  );

  test(
    'unpublish an empty event but reject hiding participant events',
    () async {
      final created = await repository.createEvent(
        input: input(),
        actor: owner,
      );
      final draft = await repository.updateEvent(
        eventId: created.id,
        input: input(EventStatus.draft),
        actor: owner,
      );
      expect(draft.status, EventStatus.draft);
      await db.collection('events').doc(created.id).update({
        'status': 'published',
        'registeredCount': 1,
      });
      await expectLater(
        repository.updateEvent(
          eventId: created.id,
          input: input(EventStatus.draft),
          actor: owner,
        ),
        throwsA(code('event-status-has-participants')),
      );
      expect(
        (await repository.getEventById(created.id, actor: owner)).status,
        EventStatus.published,
      );
    },
  );

  test(
    'cannot reopen terminal events or let another organizer publish',
    () async {
      for (final status in [EventStatus.finished, EventStatus.cancelled]) {
        await db
            .collection('events')
            .doc(status.name)
            .set(
              testEvent(
                id: status.name,
                status: status,
                registeredCount: 0,
                checkedInCount: 0,
              ).toMap(),
            );
        await expectLater(
          repository.updateEvent(
            eventId: status.name,
            input: input(EventStatus.published),
            actor: owner,
          ),
          throwsA(isA<AppException>()),
        );
        expect(
          (await repository.getEventById(status.name, actor: owner)).status,
          status,
        );
      }
      final draft = await repository.createEvent(
        input: input(EventStatus.draft),
        actor: owner,
      );
      await expectLater(
        repository.updateEvent(
          eventId: draft.id,
          input: input(EventStatus.published),
          actor: testUser(uid: 'other', role: UserRole.organizer),
        ),
        throwsA(code('event-forbidden')),
      );
    },
  );

  test(
    'same create request across restart applies requested status without duplicates',
    () async {
      final draftInput = input(
        EventStatus.draft,
      ).copyWith(createRequestId: 'stable-status');
      final draft = await repository.createEvent(
        input: draftInput,
        actor: owner,
      );
      repository = EventRepositoryImpl(firestore: db, now: () => now);
      final published = await repository.createEvent(
        input: draftInput.copyWith(status: EventStatus.published),
        actor: owner,
      );
      expect(published.id, draft.id);
      expect(published.status, EventStatus.published);
      expect((await db.collection('events').get()).docs, hasLength(1));
    },
  );

  test(
    'poster failure keeps draft private; lost publish response confirms selected status',
    () async {
      final store = PosterFirestore();
      final posters = FakePosterService();
      repository = EventRepositoryImpl(
        firestore: store,
        posterService: posters,
        now: () => now,
      );
      final draft = await repository.createEvent(
        input: input(EventStatus.draft),
        actor: owner,
      );
      final publish = input(
        EventStatus.published,
      ).copyWith(posterSelection: posterSelection());
      posters.failure = const AppException('Upload unavailable');
      await expectLater(
        repository.updateEvent(eventId: draft.id, input: publish, actor: owner),
        throwsA(isA<AppException>()),
      );
      expect(
        (await store.collection('events').doc(draft.id).get())
            .data()!['status'],
        'draft',
      );
      posters.failure = null;
      store.loseCommitResponse = true;
      await expectLater(
        repository.updateEvent(
          eventId: draft.id,
          input: publish,
          actor: owner,
          expectedUpdatedAt: draft.updatedAt,
        ),
        throwsA(isA<AppException>()),
      );
      final saved = await repository.updateEvent(
        eventId: draft.id,
        input: publish,
        actor: owner,
        expectedUpdatedAt: draft.updatedAt,
      );
      expect(saved.status, EventStatus.published);
      expect(saved.posterUrl, posters.uploaded.url);
    },
  );
}

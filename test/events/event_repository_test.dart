import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'event_fakes.dart';
import '../auth/auth_fakes.dart';

void main() {
  late FakeFirebaseFirestore db;
  late EventRepositoryImpl repo;
  final now = DateTime.utc(2030, 5, 1);
  setUp(() {
    db = FakeFirebaseFirestore();
    repo = EventRepositoryImpl(firestore: db, now: () => now);
  });
  Future<void> save(EventModel event) =>
      db.collection('events').doc(event.id).set(event.toMap());
  EventFormInput formInput({
    String title = 'Organizer Flutter Workshop',
    DateTime? startAt,
    DateTime? endAt,
  }) =>
      EventFormInput(
        title: title,
        description:
            'A practical hands-on Flutter workshop for CampusHub students.',
        category: 'technology',
        locationName: 'Hall A',
        startAt: startAt ?? DateTime.utc(2030, 6, 1, 9),
        endAt: endAt ?? DateTime.utc(2030, 6, 1, 11),
        capacity: 100,
      );

  test(
    'reads only upcoming published events, orders by time and filters category',
    () async {
      await save(testEvent(id: 'later'));
      await save(
        testEvent(id: 'soon', startAt: now.add(const Duration(days: 1))),
      );
      await save(testEvent(id: 'boundary', startAt: now));
      await save(
        testEvent(id: 'past', startAt: now.subtract(const Duration(days: 1))),
      );
      await save(testEvent(id: 'draft', status: EventStatus.draft));
      await save(testEvent(id: 'cancelled', status: EventStatus.cancelled));
      await save(testEvent(id: 'finished', status: EventStatus.finished));
      await save(testEvent(id: 'music', category: 'music'));
      final result = await repo.getUpcomingEvents();
      expect(result.map((event) => event.id), [
        'boundary',
        'soon',
        'later',
        'music',
      ]);
      expect(
        (await repo.getUpcomingEvents(
          filter: const EventFilter(category: 'music'),
        )).single.id,
        'music',
      );
      expect(
        (await repo.getUpcomingEvents(
          filter: const EventFilter(keyword: 'does not exist'),
        )),
        isEmpty,
      );
    },
  );

  test('organizer can create, update and soft-cancel an owned event', () async {
    final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);
    final created = await repo.createEvent(input: formInput(), actor: organizer);

    expect(created.organizerId, organizer.uid);
    expect(created.status, EventStatus.published);
    expect(created.registeredCount, 0);
    expect(created.checkedInCount, 0);
    expect(created.titleLower, 'organizer flutter workshop');

    final updated = await repo.updateEvent(
      eventId: created.id,
      input: formInput(title: 'Updated Flutter Workshop'),
      actor: organizer,
    );
    expect(updated.title, 'Updated Flutter Workshop');
    expect(updated.organizerId, organizer.uid);

    final cancelled = await repo.cancelEvent(
      eventId: created.id,
      actor: organizer,
    );
    expect(cancelled.status, EventStatus.cancelled);
    await expectLater(
      repo.updateEvent(
        eventId: created.id,
        input: formInput(),
        actor: organizer,
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'event-cancelled')),
    );
  });

  test('student is denied and an admin can manage another organizer event', () async {
    final owner = testUser(uid: 'organizer-1', role: UserRole.organizer);
    final otherOrganizer = testUser(uid: 'organizer-2', role: UserRole.organizer);
    final admin = testUser(uid: 'admin-1', role: UserRole.admin);
    final created = await repo.createEvent(input: formInput(), actor: owner);

    await expectLater(
      repo.createEvent(input: formInput(), actor: testUser()),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'event-forbidden')),
    );
    await expectLater(
      repo.updateEvent(
        eventId: created.id,
        input: formInput(title: 'Not owner'),
        actor: otherOrganizer,
      ),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'event-forbidden')),
    );
    await expectLater(
      repo.cancelEvent(eventId: created.id, actor: otherOrganizer),
      throwsA(isA<AppException>().having((e) => e.code, 'code', 'event-forbidden')),
    );

    final updated = await repo.updateEvent(
      eventId: created.id,
      input: formInput(title: 'Admin override'),
      actor: admin,
    );
    expect(updated.title, 'Admin override');
    expect((await repo.getManagedEvents(actor: owner)).single.id, created.id);
    expect((await repo.getManagedEvents(actor: admin)).single.id, created.id);
  });

  test('managed events are owner-filtered, ordered, and retain cancelled history', () async {
    final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);
    await save(testEvent(id: 'older', startAt: now.add(const Duration(days: 1))));
    await save(testEvent(id: 'newer', startAt: now.add(const Duration(days: 2))));
    await save(testEvent(
      id: 'cancelled',
      startAt: now.add(const Duration(days: 3)),
      status: EventStatus.cancelled,
    ));
    await save(testEvent(
      id: 'other-owner',
      organizerId: 'organizer-2',
      startAt: now.add(const Duration(days: 4)),
    ));

    final events = await repo.getManagedEvents(actor: organizer);

    expect(events.map((event) => event.id), ['cancelled', 'newer', 'older']);
  });

  test('create rejects a new published event that starts now or in the past',
      () async {
    final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);
    await expectLater(
      repo.createEvent(
        input: formInput(
          startAt: now,
          endAt: now.add(const Duration(hours: 2)),
        ),
        actor: organizer,
      ),
      throwsA(
        isA<AppException>().having(
          (error) => error.code,
          'code',
          'invalid-event-input',
        ),
      ),
    );
  });

  test('update allows an existing event whose start is in the past', () async {
    final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);
    final existing = testEvent(
      id: 'started-event',
      startAt: now.subtract(const Duration(hours: 2)),
    );
    await save(existing);

    final updated = await repo.updateEvent(
      eventId: existing.id,
      input: formInput(
        title: 'Updated started event',
        startAt: existing.startAt,
        endAt: existing.endAt,
      ),
      actor: organizer,
    );

    expect(updated.title, 'Updated started event');
  });

  test('update preserves protected ownership, counters and poster URL', () async {
    final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);
    final existing = testEvent(
      id: 'protected-fields',
      registeredCount: 4,
      checkedInCount: 2,
      posterUrl: 'https://example.invalid/poster.png',
    );
    await save(existing);

    final updated = await repo.updateEvent(
      eventId: existing.id,
      input: formInput(title: 'Updated title'),
      actor: organizer,
    );

    expect(updated.organizerId, existing.organizerId);
    expect(updated.registeredCount, existing.registeredCount);
    expect(updated.checkedInCount, existing.checkedInCount);
    expect(updated.posterUrl, existing.posterUrl);
  });

  test('update and cancel report a missing event as not found', () async {
    final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);

    for (final action in [
      () => repo.updateEvent(
            eventId: 'missing',
            input: formInput(),
            actor: organizer,
          ),
      () => repo.cancelEvent(eventId: 'missing', actor: organizer),
    ]) {
      await expectLater(
        action(),
        throwsA(
          isA<AppException>().having(
            (error) => error.code,
            'code',
            'event-not-found',
          ),
        ),
      );
    }
  });

  test(
    'details hide missing or unpublished IDs and preserve published data',
    () async {
      final event = testEvent();
      await save(event);
      final loaded = await repo.getEventById(event.id);
      expect(loaded.toMap(), event.toMap());
      await save(testEvent(id: 'draft', status: EventStatus.draft));
      for (final id in ['missing', 'draft', '', 'bad/path']) {
        await expectLater(
          repo.getEventById(id),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'event-not-found',
            ),
          ),
        );
      }
    },
  );

  test(
    'malformed event produces an actionable error instead of crashing widgets',
    () async {
      await db.collection('events').doc('bad').set({
        ...testEvent().toMap(),
        'capacity': 'one hundred',
      });
      await expectLater(
        repo.getUpcomingEvents(),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'invalid-event'),
        ),
      );
    },
  );

  test(
    'model round-trips UTC timestamps and nullable poster and coordinate fields',
    () {
      final event = testEvent();
      final map = event.toMap();
      map['latitude'] = 10;
      map['longitude'] = 105.7;
      final loaded = EventModel.fromMap(event.id, map);
      expect(loaded.latitude, 10.0);
      expect(loaded.longitude, 105.7);
      expect(loaded.startAt.isUtc, isTrue);
      expect(loaded.posterUrl, isNull);
      expect(loaded.availablePlaces, 80);
      expect(testEvent(registeredCount: 110).availablePlaces, 0);
      expect(
        () => EventModel.fromMap('bad', {...map, 'status': 'unknown'}),
        throwsFormatException,
      );
    },
  );
}

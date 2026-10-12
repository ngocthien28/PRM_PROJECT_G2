import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/events/data/models/event_filter.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'event_fakes.dart';

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

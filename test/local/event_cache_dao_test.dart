import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/events/data/models/event_model.dart';
import 'package:campushub/local/dao/event_cache_dao.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

EventModel sampleEvent({
  required String id,
  String title = 'Flutter Meetup',
  String category = 'technology',
  DateTime? startAt,
}) {
  final now = DateTime.now().toUtc();
  return EventModel(
    id: id,
    organizerId: 'org-1',
    clubId: 'club-1',
    title: title,
    description: 'A great meetup.',
    category: category,
    locationName: 'Hall A',
    startAt: startAt ?? now.add(const Duration(days: 2)),
    endAt: (startAt ?? now.add(const Duration(days: 2))).add(const Duration(hours: 2)),
    capacity: 100,
    registeredCount: 20,
    checkedInCount: 0,
    status: EventStatus.published,
    createdAt: now.subtract(const Duration(days: 5)),
    updatedAt: now.subtract(const Duration(days: 1)),
  );
}

class _OfflineFirestore extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
      message: 'Network connection lost.',
    );
  }
}

void main() {
  group('UC-028: EventCacheDao', () {
    late EventCacheDao dao;

    setUp(() {
      dao = EventCacheDao();
    });

    tearDown(() async {
      await dao.clearAll();
    });

    test('saveEvent and getCachedEvent retrieve cached event correctly', () async {
      final event = sampleEvent(id: 'ev-1', title: 'Tech Talk');
      await dao.saveEvent(event);

      final retrieved = await dao.getCachedEvent('ev-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.id, 'ev-1');
      expect(retrieved.title, 'Tech Talk');
      expect(retrieved.category, 'technology');
    });

    test('saveEvents batch inserts and getCachedEvents returns all', () async {
      final ev1 = sampleEvent(id: 'ev-1', title: 'AI Summit');
      final ev2 = sampleEvent(id: 'ev-2', title: 'Robotics Workshop');
      await dao.saveEvents([ev1, ev2]);

      final all = await dao.getCachedEvents();
      expect(all.length, 2);
      expect(all.any((e) => e.id == 'ev-1'), isTrue);
      expect(all.any((e) => e.id == 'ev-2'), isTrue);
    });

    test('deleteCachedEvent removes event by id', () async {
      final ev1 = sampleEvent(id: 'ev-1');
      await dao.saveEvent(ev1);
      expect(await dao.getCachedEvent('ev-1'), isNotNull);

      await dao.deleteCachedEvent('ev-1');
      expect(await dao.getCachedEvent('ev-1'), isNull);
    });

    test('clearAll wipes entire event cache', () async {
      await dao.saveEvents([sampleEvent(id: 'e1'), sampleEvent(id: 'e2')]);
      expect((await dao.getCachedEvents()).length, 2);

      await dao.clearAll();
      expect((await dao.getCachedEvents()).isEmpty, isTrue);
    });
  });

  group('UC-030: Offline Event Fallback in EventRepositoryImpl', () {
    late _OfflineFirestore firestore;
    late EventCacheDao dao;

    setUp(() async {
      firestore = _OfflineFirestore();
      dao = EventCacheDao();
      await dao.clearAll();
    });

    tearDown(() async {
      await dao.clearAll();
    });

    test('getUpcomingEvents falls back to SQLite cache on server failure', () async {
      final cachedEvent = sampleEvent(id: 'offline-ev-1', title: 'Offline Hackathon');
      await dao.saveEvent(cachedEvent);

      final fallbackRepo = EventRepositoryImpl(
        firestore: firestore,
        eventCacheDao: dao,
      );
      final events = await fallbackRepo.getUpcomingEvents();
      expect(events.length, 1);
      expect(events.first.id, 'offline-ev-1');
      expect(events.first.title, 'Offline Hackathon');
    });

    test('getEventById falls back to SQLite cache on network timeout', () async {
      final cachedEvent = sampleEvent(id: 'offline-detail-1', title: 'Detail Offline');
      await dao.saveEvent(cachedEvent);

      final fallbackRepo = EventRepositoryImpl(
        firestore: firestore,
        eventCacheDao: dao,
      );
      final event = await fallbackRepo.getEventById('offline-detail-1');
      expect(event.id, 'offline-detail-1');
      expect(event.title, 'Detail Offline');
    });
  });
}

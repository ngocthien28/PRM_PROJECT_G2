import 'package:campushub/features/notifications/data/notification_repository_impl.dart';
import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/local/dao/notification_cache_dao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inbox is isolated, ordered and read updates persist', () async {
    final db = FakeFirebaseFirestore();
    for (final entry in [('a', 'u1', 1), ('b', 'u1', 2), ('c', 'u2', 3)]) {
      await db.collection('notifications').doc(entry.$1).set({
        'userId': entry.$2,
        'title': entry.$1,
        'body': 'Club update',
        'type': 'club_membership',
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, entry.$3)),
      });
    }
    final cache = _MemoryNotificationCache();
    final repository = NotificationRepositoryImpl(db, cache: cache);
    expect((await repository.watchInbox('u1').first).map((n) => n.id), [
      'b',
      'a',
    ]);
    await repository.markRead('b');
    expect((await repository.watchInbox('u1').first).first.isRead, true);
    await repository.markRead('b');
    expect((await db.collection('notifications').get()).size, 3);
    expect((await cache.load('u1')).first.isRead, true);
  });

  test(
    'UC-079 shows the cached inbox immediately while Firestore refreshes',
    () async {
      final db = FakeFirebaseFirestore();
      final cache = _MemoryNotificationCache();
      final cached = AppNotification(
        id: 'offline',
        userId: 'u1',
        title: 'Saved update',
        body: 'Available without a network refresh.',
        type: 'event',
        isRead: false,
        createdAt: DateTime.utc(2026, 10, 28),
      );
      await cache.replace('u1', [cached]);

      final stream = NotificationRepositoryImpl(
        db,
        cache: cache,
      ).watchInbox('u1');
      expect((await stream.first).single.id, 'offline');
    },
  );
}

class _MemoryNotificationCache implements NotificationCache {
  final Map<String, List<AppNotification>> _items = {};

  @override
  Future<List<AppNotification>> load(String userId) async => [
    ...?_items[userId],
  ];

  @override
  Future<void> markRead(String notificationId) async {
    for (final entry in _items.entries) {
      _items[entry.key] = [
        for (final item in entry.value)
          item.id == notificationId ? item.copyWith(isRead: true) : item,
      ];
    }
  }

  @override
  Future<void> replace(
    String userId,
    List<AppNotification> notifications,
  ) async {
    _items[userId] = [...notifications];
  }
}

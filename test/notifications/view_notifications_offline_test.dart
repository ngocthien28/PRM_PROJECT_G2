import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/features/notifications/domain/usecases/view_notifications_offline.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/local/dao/notification_cache_dao.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationCache implements NotificationCache {
  final Map<String, List<AppNotification>> _storage = {};

  void seed(String userId, List<AppNotification> items) {
    _storage[userId] = items;
  }

  @override
  Future<List<AppNotification>> load(String userId) async {
    return _storage[userId] ?? const [];
  }

  @override
  Future<void> replace(String userId, List<AppNotification> notifications) async {
    _storage[userId] = notifications;
  }

  @override
  Future<void> markRead(String notificationId) async {
    for (final list in _storage.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == notificationId) {
          list[i] = list[i].copyWith(isRead: true);
        }
      }
    }
  }
}

AppNotification _sampleNotification({
  required String id,
  required String userId,
  required String title,
  required String body,
  bool isRead = false,
}) {
  return AppNotification(
    id: id,
    userId: userId,
    title: title,
    body: body,
    type: 'event_announcement',
    referenceId: 'event-101',
    createdAt: DateTime.now().toUtc(),
    isRead: isRead,
  );
}

void main() {
  group('UC-079: View Notifications Offline', () {
    test('returns cached notifications isolated by user account', () async {
      final cache = _FakeNotificationCache();
      cache.seed('user-alpha', [
        _sampleNotification(id: 'notif-1', userId: 'user-alpha', title: 'Alpha Note', body: 'Sync content'),
      ]);
      cache.seed('user-beta', [
        _sampleNotification(id: 'notif-2', userId: 'user-beta', title: 'Beta Note', body: 'Other content'),
      ]);

      final useCase = ViewNotificationsOffline(cache);

      final alphaItems = await useCase.call('user-alpha');
      expect(alphaItems.length, equals(1));
      expect(alphaItems.first.title, equals('Alpha Note'));

      final betaItems = await useCase.call('user-beta');
      expect(betaItems.length, equals(1));
      expect(betaItems.first.title, equals('Beta Note'));

      final unknownItems = await useCase.call('user-gamma');
      expect(unknownItems, isEmpty);
    });

    test('returns empty list for whitespace or empty userId', () async {
      final cache = _FakeNotificationCache();
      final useCase = ViewNotificationsOffline(cache);

      expect(await useCase.call(''), isEmpty);
      expect(await useCase.call('   '), isEmpty);
    });

    test('viewNotificationsOfflineProvider integrates cleanly with Riverpod', () async {
      final cache = _FakeNotificationCache();
      cache.seed('user-khang', [
        _sampleNotification(id: 'notif-khang', userId: 'user-khang', title: 'Khang Offline Note', body: 'Ready offline'),
      ]);

      final container = ProviderContainer(
        overrides: [notificationCacheProvider.overrideWithValue(cache)],
      );
      addTearDown(container.dispose);

      final useCase = container.read(viewNotificationsOfflineProvider);
      final items = await useCase('user-khang');
      expect(items.single.id, equals('notif-khang'));
      expect(items.single.title, equals('Khang Offline Note'));
    });
  });
}

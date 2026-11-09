import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/features/notifications/data/notification_repository.dart';
import 'package:campushub/features/notifications/domain/usecases/view_notification_details.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNotificationRepository implements NotificationRepository {
  final List<String> markedReadIds = [];

  @override
  Future<void> markRead(String notificationId) async {
    markedReadIds.add(notificationId);
  }

  @override
  Future<void> saveDeviceToken(String userId, String token) async {}

  @override
  Stream<List<AppNotification>> watchInbox(String userId) => const Stream.empty();
}

void main() {
  group('UC-090: ViewNotificationDetails', () {
    late _FakeNotificationRepository repository;
    late ViewNotificationDetails useCase;

    setUp(() {
      repository = _FakeNotificationRepository();
      useCase = ViewNotificationDetails(repository);
    });

    test('marks unread notification as read and returns updated notification', () async {
      final unread = AppNotification(
        id: 'notice-1',
        userId: 'user-1',
        title: 'Club announcement',
        body: 'Meeting tomorrow at 3 PM',
        type: 'club',
        isRead: false,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final result = await useCase(unread);

      expect(repository.markedReadIds, contains('notice-1'));
      expect(result.isRead, isTrue);
      expect(result.id, 'notice-1');
    });

    test('does not re-mark already read notification', () async {
      final read = AppNotification(
        id: 'notice-2',
        userId: 'user-1',
        title: 'Event reminder',
        body: 'Event starts in 1 hour',
        type: 'event',
        isRead: true,
        createdAt: DateTime.utc(2026, 1, 1),
      );

      final result = await useCase(read);

      expect(repository.markedReadIds, isEmpty);
      expect(result.isRead, isTrue);
    });
  });
}

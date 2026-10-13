import 'models/app_notification.dart';

abstract interface class NotificationRepository {
  Stream<List<AppNotification>> watchInbox(String userId);
  Future<void> markRead(String notificationId);
  Future<void> saveDeviceToken(String userId, String token);
}

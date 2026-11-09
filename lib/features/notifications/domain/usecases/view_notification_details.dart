import '../../data/models/app_notification.dart';
import '../../data/notification_repository.dart';

/// UC-090: View Notification Details.
/// Opens notification details, marks unread notifications as read via repository,
/// and returns the updated notification state.
class ViewNotificationDetails {
  const ViewNotificationDetails(this._repository);

  final NotificationRepository _repository;

  Future<AppNotification> call(AppNotification notification) async {
    if (!notification.isRead) {
      await _repository.markRead(notification.id);
      return notification.copyWith(isRead: true);
    }
    return notification;
  }
}

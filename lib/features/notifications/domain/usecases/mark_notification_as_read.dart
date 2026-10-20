import '../../data/notification_repository.dart';

/// UC-074: persists the read state of one inbox item.
class MarkNotificationAsRead {
  const MarkNotificationAsRead(this._repository);

  final NotificationRepository _repository;

  Future<void> call(String notificationId) =>
      _repository.markRead(notificationId);
}

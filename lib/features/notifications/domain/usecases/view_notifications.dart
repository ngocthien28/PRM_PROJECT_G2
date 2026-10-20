import '../../data/models/app_notification.dart';
import '../../data/notification_repository.dart';

/// UC-073: watches the signed-in user's notification inbox.
class ViewNotifications {
  const ViewNotifications(this._repository);

  final NotificationRepository _repository;

  Stream<List<AppNotification>> call(String userId) =>
      _repository.watchInbox(userId);
}

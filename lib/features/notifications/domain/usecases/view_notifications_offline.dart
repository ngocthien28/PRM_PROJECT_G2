import '../../../../local/dao/notification_cache_dao.dart';
import '../../data/models/app_notification.dart';

/// UC-079: Notifications - View Notifications Offline.
/// Retrieves account-scoped cached notifications from local SQLite storage
/// when device is offline or when opening inbox without network connectivity.
class ViewNotificationsOffline {
  const ViewNotificationsOffline(this._cache);

  final NotificationCache _cache;

  Future<List<AppNotification>> call(String userId) async {
    final trimmedId = userId.trim();
    if (trimmedId.isEmpty) {
      return const [];
    }
    return _cache.load(trimmedId);
  }
}

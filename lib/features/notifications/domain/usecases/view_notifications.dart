import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../local/dao/notification_cache_dao.dart';
import '../../data/models/app_notification.dart';

/// UC-073: emit cached notifications immediately, refresh from the signed-in
/// user's Firestore inbox, sort newest first, and retain an offline fallback.
class ViewNotifications {
  const ViewNotifications(this._firestore, this._cache);

  final FirebaseFirestore _firestore;
  final NotificationCache _cache;

  Stream<List<AppNotification>> call(String userId) async* {
    final saved = await _cache.load(userId);
    if (saved.isNotEmpty) yield saved;

    try {
      await for (final snapshot
          in _firestore
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .snapshots()) {
        final notifications = snapshot.docs.map((document) {
          return AppNotification.fromMap(document.id, document.data());
        }).toList();
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _cache.replace(userId, notifications);
        yield notifications;
      }
    } catch (error, stackTrace) {
      final fallback = await _cache.load(userId);
      if (fallback.isNotEmpty) {
        yield fallback;
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

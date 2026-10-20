import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../local/dao/notification_cache_dao.dart';

/// UC-074: persist read state remotely and mirror it in the local inbox cache.
class MarkNotificationAsRead {
  const MarkNotificationAsRead(this._firestore, this._cache);

  final FirebaseFirestore _firestore;
  final NotificationCache _cache;

  Future<void> call(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
    await _cache.markRead(notificationId);
  }
}

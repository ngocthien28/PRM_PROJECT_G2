import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../local/dao/notification_cache_dao.dart';
import 'models/app_notification.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this.db, {NotificationCache? cache})
    : cache = cache ?? NotificationCacheDao();
  final FirebaseFirestore db;
  final NotificationCache cache;

  @override
  Stream<List<AppNotification>> watchInbox(String userId) async* {
    final saved = await cache.load(userId);
    if (saved.isNotEmpty) yield saved;

    try {
      await for (final snapshot
          in db
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .snapshots()) {
        final items = snapshot.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await cache.replace(userId, items);
        yield items;
      }
    } catch (error, stackTrace) {
      final fallback = await cache.load(userId);
      if (fallback.isNotEmpty) {
        yield fallback;
        return;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    await db.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
    await cache.markRead(notificationId);
  }

  static String tokenId(String token) =>
      base64Url.encode(utf8.encode(token)).replaceAll('=', '');

  @override
  Future<void> saveDeviceToken(String userId, String token) => db
      .collection('users')
      .doc(userId)
      .collection('device_tokens')
      .doc(tokenId(token))
      .set({
        'token': token,
        'platform': 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> removeDeviceToken(String userId, String token) => db
      .collection('users')
      .doc(userId)
      .collection('device_tokens')
      .doc(tokenId(token))
      .delete();
}

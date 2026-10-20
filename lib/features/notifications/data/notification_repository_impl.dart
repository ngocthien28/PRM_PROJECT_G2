import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/app_notification.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  const NotificationRepositoryImpl(this.db);
  final FirebaseFirestore db;

  @override
  Stream<List<AppNotification>> watchInbox(String userId) => db
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
        final items = snapshot.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList();
        items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return items;
      });

  @override
  Future<void> markRead(String notificationId) => db
      .collection('notifications')
      .doc(notificationId)
      .update({'isRead': true});

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

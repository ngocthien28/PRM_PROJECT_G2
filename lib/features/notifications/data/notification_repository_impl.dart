import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../local/dao/notification_cache_dao.dart';
import '../domain/usecases/view_notifications.dart';
import 'models/app_notification.dart';
import 'notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this.db, {NotificationCache? cache})
    : cache = cache ?? NotificationCacheDao();
  final FirebaseFirestore db;
  final NotificationCache cache;

  @override
  Stream<List<AppNotification>> watchInbox(String userId) =>
      ViewNotifications(db, cache)(userId);

  @override
  Future<void> markRead(String notificationId) async {
    await db.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
    await cache.markRead(notificationId);
  }

  /// FEATURE: UC-007 - Log Out
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa token thành document ID ổn định dùng xóa đăng ký lúc logout.
  /// ROLE: Device token key helper
  /// CALLED FROM: removeDeviceToken; saveDeviceToken cũng dùng chung.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
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

  /// FEATURE: UC-007 - Log Out
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Xóa document device token theo UID khi unregister thiết bị lúc logout.
  /// ROLE: Logout SDK cleanup
  /// CALLED FROM: NotificationService.unregister hoặc token refresh.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK, dart:convert.
  Future<void> removeDeviceToken(String userId, String token) => db
      .collection('users')
      .doc(userId)
      .collection('device_tokens')
      .doc(tokenId(token))
      .delete();
}

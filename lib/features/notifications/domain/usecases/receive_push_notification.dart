import 'package:firebase_messaging/firebase_messaging.dart';

typedef ShowPushAlert = Future<void> Function(
  String id,
  String title,
  String body,
);

/// UC-075: validates, deduplicates, and presents a foreground push message.
class ReceivePushNotification {
  const ReceivePushNotification(this._showAlert);

  final ShowPushAlert _showAlert;

  Future<void> call({
    required RemoteMessage message,
    required String? signedInUserId,
    required Set<String> seenNotificationIds,
  }) async {
    if (signedInUserId == null ||
        message.data['userId'] != signedInUserId) {
      return;
    }
    final id = message.data['notificationId'] ?? message.messageId;
    if (id == null || !seenNotificationIds.add(id)) return;
    if (seenNotificationIds.length > 200) {
      seenNotificationIds.remove(seenNotificationIds.first);
    }
    await _showAlert(
      id,
      message.notification?.title ?? 'CampusHub',
      message.notification?.body ?? 'You have a new update.',
    );
  }
}

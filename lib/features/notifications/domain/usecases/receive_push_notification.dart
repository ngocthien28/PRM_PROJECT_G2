import 'package:firebase_messaging/firebase_messaging.dart';

typedef ShowPushAlert = Future<void> Function(
  String id,
  String title,
  String body,
);

/// UC-075: accept pushes only for the active account, deduplicate them, keep
/// the in-memory guard bounded, and show the foreground notification.
class ReceivePushNotification {
  const ReceivePushNotification(this._showAlert);

  final ShowPushAlert _showAlert;

  Future<void> call({
    required RemoteMessage message,
    required String? signedInUserId,
    required Set<String> seenNotificationIds,
  }) async {
    final recipient = message.data['userId'];
    if (signedInUserId == null || recipient != signedInUserId) return;

    final notificationId = message.data['notificationId'] ?? message.messageId;
    if (notificationId == null || !seenNotificationIds.add(notificationId)) {
      return;
    }
    if (seenNotificationIds.length > 200) {
      seenNotificationIds.remove(seenNotificationIds.first);
    }

    await _showAlert(
      notificationId,
      message.notification?.title ?? 'CampusHub',
      message.notification?.body ?? 'You have a new update.',
    );
  }

  bool shouldOpenInbox(RemoteMessage message, String? signedInUserId) =>
      signedInUserId != null && message.data['userId'] == signedInUserId;
}

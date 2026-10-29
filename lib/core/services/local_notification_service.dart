import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';

import 'desktop_notification_listener.dart';

class LocalNotificationService implements DesktopNotificationPresenter {
  static const _channel = MethodChannel('campushub/notifications');
  final Map<String, LocalNotification> _desktopNotifications = {};
  void Function(String?)? _onTap;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  Future<void> initialize(void Function(String?) onTap) async {
    _onTap = onTap;
    if (_isWindows) {
      await localNotifier.setup(
        appName: 'CampusHub',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tap') onTap(call.arguments as String?);
    });
    await _channel.invokeMethod<void>('initialize');
  }

  @override
  Future<void> show(String id, String title, String body) async {
    if (!_isWindows) {
      await _channel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'body': body,
      });
      return;
    }

    final previous = _desktopNotifications.remove(id);
    if (previous != null) await previous.destroy();
    final notification = LocalNotification(
      identifier: id,
      title: title,
      body: body,
    );
    _desktopNotifications[id] = notification;
    notification.onClick = () {
      _desktopNotifications.remove(id);
      _onTap?.call(id);
    };
    notification.onClose = (_) {
      if (identical(_desktopNotifications[id], notification)) {
        _desktopNotifications.remove(id);
      }
    };
    await notification.show();
  }

  Future<void> cancelAll() async {
    if (!_isWindows) {
      await _channel.invokeMethod<void>('cancelAll');
      return;
    }
    final notifications = _desktopNotifications.values.toList();
    _desktopNotifications.clear();
    await Future.wait(
      notifications.map((notification) => notification.close()),
    );
  }
}

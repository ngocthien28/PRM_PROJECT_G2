import 'package:flutter/services.dart';

/// Android-only native channel. Called only after platform gating in the FCM
/// service, so Windows does not acquire a native notification dependency.
class LocalNotificationService {
  static const _channel = MethodChannel('campushub/notifications');

  Future<void> initialize(void Function(String?) onTap) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'tap') onTap(call.arguments as String?);
    });
    await _channel.invokeMethod<void>('initialize');
  }

  Future<void> show(String id, String title, String body) => _channel
      .invokeMethod<void>('show', {'id': id, 'title': title, 'body': body});

  Future<void> cancelAll() => _channel.invokeMethod<void>('cancelAll');
}

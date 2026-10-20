import 'package:campushub/core/services/local_notification_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('campushub/notifications');
  test('native channel receives stable ID, body and cancellation', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final service = LocalNotificationService();
    await service.initialize((_) {});
    await service.show('notice-1', 'Club joined', 'Joined Sport');
    await service.cancelAll();
    expect(calls.map((c) => c.method), ['initialize', 'show', 'cancelAll']);
    expect(calls[1].arguments, {
      'id': 'notice-1',
      'title': 'Club joined',
      'body': 'Joined Sport',
    });
  });
}

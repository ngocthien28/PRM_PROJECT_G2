import 'package:campushub/core/services/desktop_notification_listener.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _Presenter implements DesktopNotificationPresenter {
  final calls = <({String id, String title, String body})>[];

  @override
  Future<void> show(String id, String title, String body) async {
    calls.add((id: id, title: title, body: body));
  }
}

void main() {
  test(
    'Windows listener ignores old records and shows only new user alerts',
    () async {
      final db = FakeFirebaseFirestore();
      final presenter = _Presenter();
      await db.collection('notifications').doc('old').set({
        'userId': 'u1',
        'title': 'Old alert',
        'body': 'Already in the inbox',
        'type': 'system',
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026)),
      });
      final listener = DesktopNotificationListener(db, presenter);
      addTearDown(listener.stop);

      await listener.start('u1');
      await pumpEventQueue();
      expect(presenter.calls, isEmpty);

      await db.collection('notifications').doc('new').set({
        'userId': 'u1',
        'title': 'Ticket ready',
        'body': 'Open your CampusHub ticket',
        'type': 'registration',
        'referenceId': 'event-1_u1',
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      });
      await pumpEventQueue();

      expect(presenter.calls, [
        (id: 'new', title: 'Ticket ready', body: 'Open your CampusHub ticket'),
      ]);
    },
  );
}

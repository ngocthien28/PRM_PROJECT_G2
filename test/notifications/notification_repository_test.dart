import 'package:campushub/features/notifications/data/notification_repository_impl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inbox is isolated, ordered and read updates persist', () async {
    final db = FakeFirebaseFirestore();
    for (final entry in [('a', 'u1', 1), ('b', 'u1', 2), ('c', 'u2', 3)]) {
      await db.collection('notifications').doc(entry.$1).set({
        'userId': entry.$2,
        'title': entry.$1,
        'body': 'Club update',
        'type': 'club_membership',
        'isRead': false,
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 1, entry.$3)),
      });
    }
    final repository = NotificationRepositoryImpl(db);
    expect((await repository.watchInbox('u1').first).map((n) => n.id), [
      'b',
      'a',
    ]);
    await repository.markRead('b');
    expect((await repository.watchInbox('u1').first).first.isRead, true);
    await repository.markRead('b');
    expect((await db.collection('notifications').get()).size, 3);
  });
}

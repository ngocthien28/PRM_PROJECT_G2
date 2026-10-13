import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:campushub/features/admin/data/admin_repository_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads dashboard counts from CampusHub collections', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({'role': 'student'});
    await db.collection('users').doc('u2').set({'role': 'admin'});
    await db.collection('clubs').doc('c1').set({'status': 'active'});
    await db.collection('events').doc('e1').set({'status': 'published'});
    await db.collection('events').doc('e2').set({'status': 'draft'});
    await db.collection('club_memberships').doc('m1').set({'status': 'active'});
    await db.collection('club_memberships').doc('m2').set({'status': 'left'});

    final AdminStats stats = await AdminRepositoryImpl(db).loadStats();

    expect(stats.userCount, 2);
    expect(stats.clubCount, 1);
    expect(stats.eventCount, 2);
    expect(stats.activeMembershipCount, 1);
  });
}

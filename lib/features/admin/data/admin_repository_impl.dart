import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<AdminStats> loadStats() async {
    final results = await Future.wait([
      firestore.collection('users').get(),
      firestore.collection('clubs').where('status', isEqualTo: 'active').get(),
      firestore.collection('events').get(),
      firestore
          .collection('club_memberships')
          .where('status', isEqualTo: 'active')
          .get(),
    ]);
    final activeClubIds = results[1].docs.map((doc) => doc.id).toSet();
    final activeStudentMemberships = results[3].docs.where((doc) {
      final data = doc.data();
      return data['role'] == 'member' && activeClubIds.contains(data['clubId']);
    }).length;
    return AdminStats(
      userCount: results[0].size,
      clubCount: results[1].size,
      eventCount: results[2].size,
      activeMembershipCount: activeStudentMemberships,
    );
  }
}

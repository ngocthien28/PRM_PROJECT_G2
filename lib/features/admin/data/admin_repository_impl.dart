import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  const AdminRepositoryImpl(this.firestore);

  final FirebaseFirestore firestore;

  @override
  Future<AdminStats> loadStats() async {
    final results = await Future.wait([
      firestore.collection('users').get(),
      firestore.collection('clubs').get(),
      firestore.collection('events').get(),
      firestore
          .collection('club_memberships')
          .where('status', isEqualTo: 'active')
          .get(),
    ]);
    return AdminStats(
      userCount: results[0].size,
      clubCount: results[1].size,
      eventCount: results[2].size,
      activeMembershipCount: results[3].size,
    );
  }
}

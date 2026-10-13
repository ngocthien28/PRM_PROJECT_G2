import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/admin_repository.dart';

/// UC-076: load dashboard totals and count only active student memberships
/// that belong to active clubs.
class ViewAdminDashboard {
  const ViewAdminDashboard(this._firestore);

  final FirebaseFirestore _firestore;

  Future<AdminStats> call() async {
    final results = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('clubs').where('status', isEqualTo: 'active').get(),
      _firestore.collection('events').get(),
      _firestore
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

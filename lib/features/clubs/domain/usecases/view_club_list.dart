import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../data/models/club_model.dart';

/// UC-067: query, map, and sort the live directory of active clubs.
class ViewClubList {
  const ViewClubList(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<ClubModel>> call() => _firestore
      .collection(FirestoreCollections.clubs)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) {
        final clubs = snapshot.docs.map(ClubModel.fromFirestore).toList();
        clubs.sort((a, b) => a.nameLower.compareTo(b.nameLower));
        return clubs;
      });
}

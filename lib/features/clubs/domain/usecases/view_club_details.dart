import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../data/models/club_model.dart';

/// UC-068: watch one club document and expose its current details.
class ViewClubDetails {
  const ViewClubDetails(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<ClubModel?> call(String clubId) => _firestore
      .collection(FirestoreCollections.clubs)
      .doc(clubId)
      .snapshots()
      .map(
        (document) =>
            document.exists ? ClubModel.fromFirestore(document) : null,
      );
}

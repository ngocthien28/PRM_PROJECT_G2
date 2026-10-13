import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/enums/club_status.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/data/models/app_user.dart';
import '../../data/models/club_model.dart';

/// UC-071: authorize the owner/admin and soft-delete a club so membership
/// history remains available.
class DeactivateClub {
  const DeactivateClub(this._firestore);

  final FirebaseFirestore _firestore;

  Future<ClubModel> call({
    required String clubId,
    required AppUser actor,
  }) async {
    final reference = _firestore
        .collection(FirestoreCollections.clubs)
        .doc(clubId);
    final document = await reference.get();
    if (!document.exists) throw const AppException('Club not found.');
    final club = ClubModel.fromFirestore(document);

    if (!actor.isActive || !actor.role.canOrganize) {
      throw const AppException('Organizer or admin access is required.');
    }
    if (actor.role != UserRole.admin && club.ownerId != actor.uid) {
      throw const AppException('Only the Club owner or an admin can do this.');
    }

    await reference.update({
      'status': ClubStatus.cancelled.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return club.copyWith(status: ClubStatus.cancelled);
  }
}

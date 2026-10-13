import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/club_logo_service.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

/// UC-070: authorize the owner/admin, optionally upload a new logo, and
/// persist the edited club fields.
class UpdateClub {
  const UpdateClub(this._firestore, this._logos);

  final FirebaseFirestore _firestore;
  final ClubLogoService _logos;

  Future<ClubModel> call({
    required String clubId,
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? newLogo,
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

    ClubLogoUpload? upload;
    if (newLogo != null) upload = await _logos.uploadLogo(newLogo);
    final updated = club.copyWith(
      name: name.trim(),
      description: description.trim(),
      logoUrl: upload?.secureUrl,
      logoPublicId: upload?.publicId,
      updatedAt: DateTime.now().toUtc(),
    );
    await reference.update(updated.toMap());
    return updated;
  }
}

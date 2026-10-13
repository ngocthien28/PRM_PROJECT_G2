import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/club_logo_service.dart';
import '../../../../shared/enums/club_status.dart';
import '../../../auth/data/models/app_user.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_membership.dart';
import '../../data/models/club_model.dart';

/// UC-069: validate the actor, upload the logo, and atomically create the
/// club together with its manager membership.
class CreateClub {
  const CreateClub(this._firestore, this._logos);

  final FirebaseFirestore _firestore;
  final ClubLogoService _logos;

  Future<ClubModel> call({
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? logo,
  }) async {
    if (!actor.isActive || !actor.role.canOrganize) {
      throw const AppException('Organizer or admin access is required.');
    }

    final clubs = _firestore.collection(FirestoreCollections.clubs);
    final memberships = _firestore.collection(
      FirestoreCollections.clubMemberships,
    );
    final clubReference = clubs.doc();
    final now = DateTime.now().toUtc();

    ClubLogoUpload? upload;
    if (logo != null) {
      final uploadTimer = Stopwatch()..start();
      upload = await _logos.uploadLogo(logo);
      if (kDebugMode) {
        debugPrint(
          '[CampusHub perf] club.logo.upload: '
          '${uploadTimer.elapsedMilliseconds} ms',
        );
      }
    }

    final club = ClubModel(
      id: clubReference.id,
      ownerId: actor.uid,
      name: name.trim(),
      description: description.trim(),
      logoUrl: upload?.secureUrl,
      logoPublicId: upload?.publicId,
      memberCount: 0,
      status: ClubStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    final batch = _firestore.batch()
      ..set(clubReference, club.toMap())
      ..set(
        memberships.doc(ClubMembership.documentId(clubReference.id, actor.uid)),
        {
          'clubId': clubReference.id,
          'userId': actor.uid,
          'role': 'manager',
          'status': 'active',
          'joinedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        },
      );

    final writeTimer = Stopwatch()..start();
    await batch.commit();
    if (kDebugMode) {
      debugPrint(
        '[CampusHub perf] club.create.commit: '
        '${writeTimer.elapsedMilliseconds} ms',
      );
    }
    return club;
  }
}

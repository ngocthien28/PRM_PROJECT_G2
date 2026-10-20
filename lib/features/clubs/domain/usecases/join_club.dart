import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/firestore_collections.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/data/models/app_user.dart';
import '../../data/models/club_membership.dart';
import '../../data/models/club_model.dart';

/// UC-072: atomically create/reactivate membership, increment memberCount,
/// and enqueue the membership notification.
class JoinClub {
  const JoinClub(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> call({required String clubId, required AppUser actor}) async {
    final timer = Stopwatch()..start();
    final clubs = _firestore.collection(FirestoreCollections.clubs);
    final memberships = _firestore.collection(
      FirestoreCollections.clubMemberships,
    );
    final notification = _firestore.collection('notifications').doc();

    try {
      await _firestore.runTransaction((transaction) async {
        if (!actor.isActive || actor.role != UserRole.student) {
          throw const AppException('Only active students can join Clubs.');
        }

        final clubReference = clubs.doc(clubId);
        final membershipReference = memberships.doc(
          ClubMembership.documentId(clubId, actor.uid),
        );
        final clubDocument = await transaction.get(clubReference);
        final membershipDocument = await transaction.get(membershipReference);
        if (!clubDocument.exists) {
          throw const AppException('Club not found.');
        }

        final club = ClubModel.fromFirestore(clubDocument);
        final alreadyJoined =
            membershipDocument.exists &&
            membershipDocument.data()?['status'] == 'active';
        if (!club.isActive) throw const AppException('Club is not active.');
        if (alreadyJoined) {
          throw const AppException('You already joined this Club.');
        }

        transaction.set(membershipReference, {
          'clubId': clubId,
          'userId': actor.uid,
          'role': 'member',
          'status': 'active',
          'joinedAt':
              membershipDocument.data()?['joinedAt'] ??
              FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(clubReference, {
          'memberCount': club.memberCount + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(notification, {
          'userId': actor.uid,
          'title': 'Club joined',
          'body': 'You joined ${club.name}.',
          'type': 'club_membership',
          'referenceId': clubId,
          'membershipStatus': 'active',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'pushStatus': 'pending',
        });
      });
    } finally {
      if (kDebugMode) {
        debugPrint(
          '[CampusHub perf] club.join.transaction: '
          '${timer.elapsedMilliseconds} ms',
        );
      }
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/club_logo_service.dart';
import '../../../shared/enums/club_status.dart';
import '../../../shared/enums/user_role.dart';
import '../../auth/data/models/app_user.dart';
import 'club_repository.dart';
import 'models/club_membership.dart';
import 'models/club_model.dart';

class ClubRepositoryImpl implements ClubRepository {
  ClubRepositoryImpl(this.db, this.logos);
  final FirebaseFirestore db;
  final ClubLogoService logos;
  CollectionReference<Map<String, dynamic>> get clubs =>
      db.collection(FirestoreCollections.clubs);
  CollectionReference<Map<String, dynamic>> get members =>
      db.collection(FirestoreCollections.clubMemberships);
  @override
  Stream<List<ClubModel>> watchClubs() => clubs
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map(
        (s) =>
            s.docs.map(ClubModel.fromFirestore).toList()
              ..sort((a, b) => a.nameLower.compareTo(b.nameLower)),
      );
  @override
  Stream<ClubModel?> watchClub(String id) => clubs
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? ClubModel.fromFirestore(d) : null);
  @override
  Stream<ClubMembership?> watchMembership(String c, String u) {
    final reference = members.doc(ClubMembership.documentId(c, u));
    return reference.snapshots().map(
      (document) =>
          document.exists ? ClubMembership.fromFirestore(document) : null,
    );
  }

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Yêu cầu actor active và canOrganize để quản lý club.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: createClub và owner.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK.
  void manager(AppUser a) {
    if (!a.isActive || !a.role.canOrganize) {
      throw const AppException('Organizer or admin access is required.');
    }
  }

  Future<ClubModel> getClub(String id) async {
    final d = await clubs.doc(id).get();
    if (!d.exists) throw const AppException('Club not found.');
    return ClubModel.fromFirestore(d);
  }

  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kết hợp manager với owner hoặc admin để cho sửa/hủy club.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: updateClub và cancelClub.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK.
  void owner(AppUser a, ClubModel c) {
    manager(a);
    if (a.role != UserRole.admin && c.ownerId != a.uid) {
      throw const AppException('Only the Club owner or an admin can do this.');
    }
  }

  @override
  Future<ClubModel> createClub({
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? logo,
  }) async {
    manager(actor);
    final r = clubs.doc(), now = DateTime.now().toUtc();
    ClubLogoUpload? up;
    if (logo != null) {
      final uploadTimer = Stopwatch()..start();
      up = await logos.uploadLogo(logo);
      if (kDebugMode) {
        debugPrint(
          '[CampusHub perf] club.logo.upload: ${uploadTimer.elapsedMilliseconds} ms',
        );
      }
    }
    final c = ClubModel(
      id: r.id,
      ownerId: actor.uid,
      name: name.trim(),
      description: description.trim(),
      logoUrl: up?.secureUrl,
      logoPublicId: up?.publicId,
      memberCount: 0,
      status: ClubStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    final b = db.batch()
      ..set(r, c.toMap())
      ..set(members.doc(ClubMembership.documentId(r.id, actor.uid)), {
        'clubId': r.id,
        'userId': actor.uid,
        'role': 'manager',
        'status': 'active',
        'joinedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    final writeTimer = Stopwatch()..start();
    await b.commit();
    if (kDebugMode) {
      debugPrint(
        '[CampusHub perf] club.create.commit: ${writeTimer.elapsedMilliseconds} ms',
      );
    }
    return c;
  }

  @override
  Future<ClubModel> updateClub({
    required String clubId,
    required String name,
    required String description,
    required AppUser actor,
    ClubLogoSource? newLogo,
  }) async {
    final c = await getClub(clubId);
    owner(actor, c);
    ClubLogoUpload? up;
    if (newLogo != null) up = await logos.uploadLogo(newLogo);
    final n = c.copyWith(
      name: name.trim(),
      description: description.trim(),
      logoUrl: up?.secureUrl,
      logoPublicId: up?.publicId,
      updatedAt: DateTime.now().toUtc(),
    );
    await clubs.doc(clubId).update(n.toMap());
    return n;
  }

  @override
  Future<ClubModel> cancelClub({
    required String clubId,
    required AppUser actor,
  }) async {
    final c = await getClub(clubId);
    owner(actor, c);
    await clubs.doc(clubId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return c.copyWith(status: ClubStatus.cancelled);
  }

  @override
  Future<void> joinClub({required String clubId, required AppUser actor}) =>
      membership(clubId, actor, true);
  @override
  Future<void> leaveClub({required String clubId, required AppUser actor}) =>
      membership(clubId, actor, false);
  /// FEATURE: UC-015 - Integrate Role-Based Access Across Modules
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Chặn join/leave nếu actor không phải student active trước khi ghi transaction.
  /// ROLE: Cross-module role/access integration
  /// CALLED FROM: joinClub và leaveClub.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK.
  Future<void> membership(String id, AppUser a, bool join) {
    final timer = Stopwatch()..start();
    final notification = db.collection('notifications').doc();
    return db
        .runTransaction((tx) async {
          if (!a.isActive || a.role != UserRole.student) {
            throw const AppException('Only active students can join Clubs.');
          }
          final cr = clubs.doc(id),
              mr = members.doc(ClubMembership.documentId(id, a.uid)),
              cd = await tx.get(cr),
              md = await tx.get(mr);
          if (!cd.exists) throw const AppException('Club not found.');
          final c = ClubModel.fromFirestore(cd),
              active = md.exists && md.data()?['status'] == 'active';
          if (!c.isActive) throw const AppException('Club is not active.');
          if (join == active) {
            throw AppException(
              join
                  ? 'You already joined this Club.'
                  : 'You are not an active member.',
            );
          }
          tx.set(mr, {
            'clubId': id,
            'userId': a.uid,
            'role': 'member',
            'status': join ? 'active' : 'left',
            'joinedAt': md.data()?['joinedAt'] ?? FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.update(cr, {
            'memberCount': join
                ? c.memberCount + 1
                : (c.memberCount > 0 ? c.memberCount - 1 : 0),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(notification, {
            'userId': a.uid,
            'title': join ? 'Club joined' : 'Club left',
            'body': join ? 'You joined ${c.name}.' : 'You left ${c.name}.',
            'type': 'club_membership',
            'referenceId': id,
            'membershipStatus': join ? 'active' : 'left',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'pushStatus': 'pending',
          });
        })
        .whenComplete(() {
          if (kDebugMode) {
            debugPrint(
              '[CampusHub perf] club.${join ? 'join' : 'leave'}.transaction: ${timer.elapsedMilliseconds} ms',
            );
          }
        });
  }
}

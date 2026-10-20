import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_collections.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../auth/data/models/app_user.dart';
import 'profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final FirebaseFirestore firestore;
  ProfileRepositoryImpl(this.firestore);

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String phone,
  }) async {
    try {
      await firestore.collection(FirestoreCollections.users).doc(uid).update({
        'displayName': displayName.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> updateAvatar({
    required String uid,
    required String avatarUrl,
  }) async {
    try {
      await firestore.collection(FirestoreCollections.users).doc(uid).update({
        'avatarUrl': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Stream<AppUser?> watchUser(String uid) async* {
    try {
      await for (final snapshot
          in firestore
              .collection(FirestoreCollections.users)
              .doc(uid)
              .snapshots()) {
        final data = snapshot.data();
        if (data == null) {
          yield null;
          continue;
        }
        // Local snapshots can precede resolution of server timestamps.
        if (snapshot.metadata.hasPendingWrites &&
            (data['createdAt'] == null || data['updatedAt'] == null)) {
          continue;
        }
        final user = AppUser.fromMap(data);
        if (user.uid != uid) {
          throw const AppException(
            'The account profile is invalid. Contact support.',
            code: 'invalid-profile',
          );
        }
        yield user;
      }
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  @override
  Future<void> ensureInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    try {
      final doc = firestore.collection(FirestoreCollections.users).doc(uid);
      await firestore.runTransaction((transaction) async {
        if ((await transaction.get(doc)).exists) return;
        transaction.set(doc, {
          'uid': uid,
          'email': email.trim().toLowerCase(),
          'displayName': displayName.trim(),
          'avatarUrl': null,
          'role': 'student',
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }
}

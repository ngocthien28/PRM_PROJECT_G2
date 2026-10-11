import '../../auth/data/models/app_user.dart';

abstract class ProfileRepository {
  Stream<AppUser?> watchUser(String uid);

  /// Creates a student profile only if absent. Never changes existing roles.
  Future<void> ensureInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  });
}

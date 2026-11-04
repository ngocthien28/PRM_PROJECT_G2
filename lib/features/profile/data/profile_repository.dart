import '../../auth/data/models/app_user.dart';

abstract class ProfileRepository {
  /// FEATURE: UC-002, UC-008
  /// MODULE: Profile Management
  /// DESCRIPTION: Khai báo hợp đồng watchUser dùng chung cho Auth và Profile.
  /// ROLE: Profile repository contract
  /// CALLED FROM: currentUserProvider, AuthRepositoryImpl hoặc ProfileViewModel.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart.
  Stream<AppUser?> watchUser(String uid);

  /// Creates a student profile only if absent. Never changes existing roles.
  /// FEATURE: UC-004 - Register Account
  /// MODULE: Profile Management
  /// DESCRIPTION: Khai báo hợp đồng ensureInitialProfile dùng chung cho Auth và Profile.
  /// ROLE: Profile repository contract
  /// CALLED FROM: currentUserProvider, AuthRepositoryImpl hoặc ProfileViewModel.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart.
  Future<void> ensureInitialProfile({
    required String uid,
    required String email,
    required String displayName,
  });

  /// FEATURE: UC-009 - Update Profile
  /// MODULE: Profile Management
  /// DESCRIPTION: Khai báo hợp đồng updateProfile dùng chung cho Auth và Profile.
  /// ROLE: Profile repository contract
  /// CALLED FROM: currentUserProvider, AuthRepositoryImpl hoặc ProfileViewModel.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart.
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    required String phone,
  });
  /// FEATURE: UC-010 - Update Profile Avatar
  /// MODULE: Profile Management
  /// DESCRIPTION: Khai báo hợp đồng updateAvatar dùng chung cho Auth và Profile.
  /// ROLE: Profile repository contract
  /// CALLED FROM: currentUserProvider, AuthRepositoryImpl hoặc ProfileViewModel.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart.
  Future<void> updateAvatar({required String uid, required String avatarUrl});
}

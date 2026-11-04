import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

/// FEATURE: UC-009, UC-010, UC-013
/// MODULE: Profile Management
/// DESCRIPTION: Cung cấp AsyncValue action cho cập nhật thông tin và avatar.
/// ROLE: Profile action state
/// CALLED FROM: ProfileScreen và EditProfileScreen.
/// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
/// TECHNOLOGY: Dart, Riverpod, image_picker.
final profileActionProvider =
    NotifierProvider<ProfileViewModel, AsyncValue<String?>>(
      ProfileViewModel.new,
    );

/// FEATURE: UC-010 - Update Profile Avatar
/// MODULE: Profile Management
/// DESCRIPTION: Tiêm ImagePicker cho gallery và cho phép test override.
/// ROLE: Gallery dependency
/// CALLED FROM: ProfileViewModel.chooseAvatar.
/// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
/// TECHNOLOGY: Dart, Riverpod, image_picker.
final profileImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);

class ProfileViewModel extends Notifier<AsyncValue<String?>> {
  /// FEATURE: UC-009, UC-010, UC-013
  /// MODULE: Profile Management
  /// DESCRIPTION: Theo dõi UID auth để reset feedback khi đổi tài khoản.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: Riverpod Notifier lifecycle.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  @override
  AsyncValue<String?> build() {
    ref.watch(authStateProvider.select((auth) => auth.asData?.value?.uid));
    return const AsyncData(null);
  }

  /// FEATURE: UC-009, UC-010
  /// MODULE: Profile Management
  /// DESCRIPTION: Lấy UID identity hiện tại cho thao tác profile.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: updateProfile, chooseAvatar và _run.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  String? get _uid => ref.read(authStateProvider).asData?.value?.uid;

  /// FEATURE: UC-009, UC-012
  /// MODULE: Profile Management
  /// DESCRIPTION: Validate name/phone trước repository write; dùng action wrapper bảo vệ phiên.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: EditProfileScreen Save changes.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  Future<void> updateProfile(String name, String phone) async {
    final uid = _uid;
    await _run(uid, () async {
      final validation =
          Validators.displayName(name) ?? Validators.phone(phone);
      if (validation != null) throw AppException(validation);
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(uid: uid!, displayName: name, phone: phone);
    }, 'Profile updated.');
  }

  /// FEATURE: UC-010 - Update Profile Avatar
  /// MODULE: Profile Management
  /// DESCRIPTION: Chọn ảnh gallery, đọc bytes, upload rồi lưu URL; bỏ kết quả khi UID đổi hoặc notifier dispose.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: ProfileScreen Change profile photo.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  Future<void> chooseAvatar() async {
    if (state.isLoading) return;
    final uid = _uid;
    state = const AsyncLoading();
    try {
      _requireSession(uid);
      final image = await ref
          .read(profileImagePickerProvider)
          .pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 1200,
          );
      if (!ref.mounted || _uid != uid) return;
      if (image == null) {
        state = const AsyncData(null);
        return;
      }
      final bytes = await image.readAsBytes();
      if (!ref.mounted || _uid != uid) return;
      final url = await ref
          .read(storageServiceProvider)
          .uploadAvatar(uid: uid!, bytes: bytes, fileName: image.name);
      if (!ref.mounted || _uid != uid) return;
      await ref
          .read(profileRepositoryProvider)
          .updateAvatar(uid: uid, avatarUrl: url);
      if (ref.mounted && _uid == uid) {
        ref.invalidate(currentUserProvider);
        state = const AsyncData('Profile photo updated.');
      }
    } catch (error, stack) {
      if (ref.mounted && _uid == uid) {
        state = AsyncError(mapError(error, stack), stack);
      }
    }
  }

  /// FEATURE: UC-009, UC-010
  /// MODULE: Profile Management
  /// DESCRIPTION: Từ chối thao tác khi không có UID phiên.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: chooseAvatar và _run.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  void _requireSession(String? uid) {
    if (uid == null) {
      throw const AppException('Please sign in again.', code: 'session-ended');
    }
  }

  /// FEATURE: UC-009, UC-013
  /// MODULE: Profile Management
  /// DESCRIPTION: Chặn request trùng và chỉ publish feedback/invalidate profile cho đúng UID.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: updateProfile.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  Future<void> _run(
    String? uid,
    Future<void> Function() action,
    String message,
  ) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      _requireSession(uid);
      await action();
      if (!ref.mounted || _uid != uid) return;
      ref.invalidate(currentUserProvider);
      if (ref.mounted) state = AsyncData(message);
    } catch (error, stack) {
      if (ref.mounted && _uid == uid) {
        state = AsyncError(mapError(error, stack), stack);
      }
    }
  }

  /// FEATURE: UC-009, UC-010, UC-013
  /// MODULE: Profile Management
  /// DESCRIPTION: Xóa feedback khi không bận; hiện chưa có production caller.
  /// ROLE: Profile state / session-safe action
  /// CALLED FROM: ProfileViewModel API; chưa được UI gọi.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, image_picker.
  void clearFeedback() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}

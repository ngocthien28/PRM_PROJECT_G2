import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

final profileActionProvider =
    NotifierProvider<ProfileViewModel, AsyncValue<String?>>(
      ProfileViewModel.new,
    );

final profileImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);

class ProfileViewModel extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() {
    ref.watch(authStateProvider.select((auth) => auth.asData?.value?.uid));
    return const AsyncData(null);
  }

  String? get _uid => ref.read(authStateProvider).asData?.value?.uid;

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

  void _requireSession(String? uid) {
    if (uid == null) {
      throw const AppException('Please sign in again.', code: 'session-ended');
    }
  }

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

  void clearFeedback() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}

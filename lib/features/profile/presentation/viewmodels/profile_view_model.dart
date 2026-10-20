import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

final profileActionProvider =
    NotifierProvider<ProfileViewModel, AsyncValue<String?>>(
      ProfileViewModel.new,
    );

class ProfileViewModel extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  String? get _uid => ref.read(authStateProvider).asData?.value?.uid;

  Future<void> updateProfile(String name, String phone) async {
    final uid = _uid;
    if (uid == null) return;
    await _run(
      () => ref
          .read(profileRepositoryProvider)
          .updateProfile(uid: uid, displayName: name, phone: phone),
      'Profile updated.',
    );
  }

  Future<void> chooseAvatar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (image == null) return;
      state = const AsyncLoading();
      final bytes = await image.readAsBytes();
      final url = await ref
          .read(storageServiceProvider)
          .uploadAvatar(uid: uid, bytes: bytes, fileName: image.name);
      await ref
          .read(profileRepositoryProvider)
          .updateAvatar(uid: uid, avatarUrl: url);
      ref.invalidate(currentUserProvider);
      if (ref.mounted) state = const AsyncData('Profile photo updated.');
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(mapError(error, stack), stack);
    }
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await action();
      ref.invalidate(currentUserProvider);
      if (ref.mounted) state = AsyncData(message);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(mapError(error, stack), stack);
    }
  }

  void clearFeedback() => state = const AsyncData(null);
}

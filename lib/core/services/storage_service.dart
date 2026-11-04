import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../errors/app_exception.dart';

class StorageService {
  StorageService(this.storage);
  final FirebaseStorage storage;

  /// FEATURE: UC-010 - Update Profile Avatar
  /// MODULE: Profile Management
  /// DESCRIPTION: Kiểm tra extension JPG/PNG/WebP và kích thước 1 byte–5 MB; upload vào avatars/uid và trả download URL.
  /// ROLE: Firebase Storage SDK / avatar validation
  /// CALLED FROM: ProfileViewModel.chooseAvatar.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Firebase Storage SDK.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    const mimeTypes = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    };
    final contentType = mimeTypes[ext];
    if (contentType == null) {
      throw const AppException('Avatar must be JPG, PNG, or WebP.');
    }
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const AppException('Avatar must be between 1 byte and 5 MB.');
    }
    try {
      final ref = storage.ref('avatars/$uid/avatar.$ext');
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } catch (error) {
      throw AppException(
        'Could not upload avatar. $error',
        code: 'avatar-upload-failed',
      );
    }
  }
}

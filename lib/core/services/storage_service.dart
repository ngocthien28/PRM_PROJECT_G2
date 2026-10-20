import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../errors/app_exception.dart';

class StorageService {
  StorageService(this.storage);
  final FirebaseStorage storage;

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

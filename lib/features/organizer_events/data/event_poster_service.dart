import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_exception.dart';
import 'models/event_form_input.dart';

/// Shared picker/upload policy: 5 MiB, JPEG/PNG/WebP, decodable image content.
class EventPosterValidator {
  static const maxBytes = 5 * 1024 * 1024;
  static const mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static Never _invalid() => throw const AppException(
    'Choose a valid JPG, PNG, or WebP image.',
    code: 'invalid-poster',
  );

  static void _checkSize(int length) {
    if (length <= 0 || length > maxBytes) {
      throw const AppException(
        'Poster must be between 1 byte and 5 MB.',
        code: 'poster-too-large',
      );
    }
  }

  static Future<EventPosterSelection> readFile(XFile file) async {
    final length = await file.length();
    _checkSize(length);
    final builder = BytesBuilder(copy: false);
    // Bound the read even if the file changes after checking its length.
    await for (final chunk in file.openRead(0, length)) {
      _checkSize(builder.length + chunk.length);
      builder.add(chunk);
    }
    final selection = EventPosterSelection(
      localUri: Uri.tryParse(file.path) ?? Uri(),
      fileName: file.name,
      mimeType: file.mimeType,
      bytes: builder.takeBytes(),
    );
    final mime = await validate(selection);
    return EventPosterSelection(
      localUri: selection.localUri,
      fileName: selection.fileName,
      mimeType: mime,
      byteLength: selection.bytes!.length,
      bytes: selection.bytes,
    );
  }

  static Future<String> validate(EventPosterSelection selection) async {
    final bytes = selection.bytes;
    if (bytes == null) _invalid();
    _checkSize(bytes.length);
    final name = selection.fileName ?? selection.localUri.path;
    final mime = mimeTypes[name.split('.').last.toLowerCase()];
    if (mime == null ||
        (selection.mimeType != null && selection.mimeType != mime)) {
      _invalid();
    }
    bool starts(List<int> signature, [int offset = 0]) =>
        bytes.length >= offset + signature.length &&
        signature.indexed.every(
          (entry) => bytes[offset + entry.$1] == entry.$2,
        );
    final matches = switch (mime) {
      'image/jpeg' => starts([0xff, 0xd8, 0xff]),
      'image/png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
      'image/webp' => starts([82, 73, 70, 70]) && starts([87, 69, 66, 80], 8),
      _ => false,
    };
    if (!matches) _invalid();
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.FrameInfo? frame;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Bound decoded memory as well as the compressed file size.
      if (descriptor.width * descriptor.height > 40000000) {
        throw const AppException(
          'Poster dimensions are too large. Choose an image under 40 megapixels.',
          code: 'invalid-poster',
        );
      }
      codec = await descriptor.instantiateCodec();
      frame = await codec.getNextFrame();
    } on AppException {
      rethrow;
    } catch (_) {
      _invalid();
    } finally {
      frame?.image.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
    return mime;
  }
}

class EventPosterPicker {
  EventPosterPicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  Future<EventPosterSelection?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    return file == null ? null : EventPosterValidator.readFile(file);
  }
}

class UploadedEventPoster {
  const UploadedEventPoster({
    required this.path,
    required this.url,
    this.deleteToken,
  });
  final String path;
  final String url;

  /// Short-lived Cloudinary capability; kept in memory, never saved to Firestore.
  final String? deleteToken;
}

abstract interface class EventPosterService {
  Future<UploadedEventPoster> upload(
    String eventId,
    EventPosterSelection image,
  );
  Future<void> delete(UploadedEventPoster poster);
}

class FirebaseEventPosterService implements EventPosterService {
  FirebaseEventPosterService(this.storage, {this.onProgress});
  final FirebaseStorage storage;
  final void Function(double? progress)? onProgress;

  @override
  Future<UploadedEventPoster> upload(
    String eventId,
    EventPosterSelection image,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(eventId)) {
      throw const AppException('Invalid event.', code: 'invalid-event');
    }
    final mime = await EventPosterValidator.validate(image);
    final extension = mime == 'image/jpeg' ? 'jpg' : mime.split('/').last;
    final reference = storage.ref(
      'events/$eventId/${const Uuid().v4()}.$extension',
    );
    onProgress?.call(0);
    var uploadCompleted = false;
    try {
      final task = reference.putData(
        image.bytes!,
        SettableMetadata(contentType: mime),
      );
      final subscription = task.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      }, onError: (Object _) {}); // The awaited task handles the same error.
      try {
        await task;
        uploadCompleted = true;
      } finally {
        await subscription.cancel();
      }
      final url = await reference.getDownloadURL();
      return UploadedEventPoster(path: reference.fullPath, url: url);
    } on FirebaseException catch (error) {
      final code = error.code.replaceFirst(RegExp(r'^storage/'), '');
      if (kDebugMode) {
        debugPrint(
          'Event poster upload failed [$code] '
          'bucket=${reference.bucket}, event=$eventId: ${error.message ?? 'No details provided.'}',
        );
      }
      final message = switch (code) {
        'bucket-not-found' || 'project-not-found' || 'no-default-bucket' =>
          'Poster storage is not configured. Contact the administrator.',
        'object-not-found' =>
          'The uploaded poster could not be found. Check the storage configuration and try again.',
        'quota-exceeded' =>
          'Poster storage is unavailable because its quota has been exceeded. Contact the administrator.',
        'unauthorized' || 'unauthenticated' || 'permission-denied' =>
          'You do not have permission to upload this event poster.',
        'canceled' => 'Poster upload was cancelled. Select Save to retry.',
        'retry-limit-exceeded' || 'network-request-failed' || 'unavailable' =>
          'Poster upload could not connect to storage. Check your connection and select Save to retry.',
        _ =>
          'Poster upload failed. Please try again or contact the administrator.',
      };
      // A completed upload whose URL lookup failed is safe to remove: no URL
      // has been returned to the repository, so it cannot be referenced there.
      if (uploadCompleted) {
        try {
          await reference.delete().timeout(const Duration(seconds: 3));
        } catch (_) {}
      }
      throw AppException(message, code: 'poster-upload-failed', cause: error);
    } finally {
      onProgress?.call(null);
    }
  }

  @override
  Future<void> delete(UploadedEventPoster poster) =>
      storage.ref(poster.path).delete();
}

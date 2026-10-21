import 'dart:typed_data';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'poster_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final entry in [
    ('JPG', posterJpeg, 'jpg', 'image/jpeg'),
    ('PNG', posterPng, 'png', 'image/png'),
    ('WebP', posterWebp, 'webp', 'image/webp'),
  ]) {
    test(
      'accepts decodable ${entry.$1} and returns the correct MIME',
      () async {
        final selected = await EventPosterValidator.readFile(
          XFile.fromData(
            entry.$2,
            name: 'poster.${entry.$3}',
            path: 'poster.${entry.$3}',
            mimeType: entry.$4,
          ),
        );
        expect(selected.mimeType, entry.$4);
        expect(selected.bytes, entry.$2);
        expect(selected.byteLength, entry.$2.length);
      },
    );
  }
  test('rejects non-image content with an image filename and MIME', () async {
    await expectLater(
      EventPosterValidator.validate(
        posterSelection(bytes: Uint8List.fromList([37, 80, 68, 70])),
      ),
      throwsA(isA<AppException>()),
    );
  });
  test(
    'rejects unsupported extension, mismatched MIME and disguised PNG',
    () async {
      for (final image in [
        posterSelection(name: 'note.pdf'),
        posterSelection(mime: 'application/pdf'),
        posterSelection(name: 'poster.jpg', mime: 'image/jpeg'),
      ]) {
        await expectLater(
          EventPosterValidator.validate(image),
          throwsA(isA<AppException>()),
        );
      }
    },
  );
  test('rejects a truncated image that has a valid signature', () async {
    await expectLater(
      EventPosterValidator.validate(
        posterSelection(
          bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
        ),
      ),
      throwsA(isA<AppException>()),
    );
  });
  test('rejects empty and oversized files before reading/decoding', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List(EventPosterValidator.maxBytes + 1),
    ]) {
      await expectLater(
        EventPosterValidator.readFile(XFile.fromData(bytes, name: 'large.png')),
        throwsA(isA<AppException>()),
      );
    }
  });
  test(
    'supports an absent platform MIME using extension, signature and decoder',
    () async {
      expect(
        await EventPosterValidator.validate(posterSelection(mime: null)),
        'image/png',
      );
    },
  );
}

import 'dart:io';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'UC-047 demo PNG passes the production poster content and size policy',
    () async {
      final file = File('firebase/fixtures/organizer-poster.png');
      final bytes = await file.readAsBytes();
      expect(
        await EventPosterValidator.validate(
          EventPosterSelection(
            localUri: file.absolute.uri,
            fileName: 'organizer-poster.png',
            mimeType: 'image/png',
            bytes: bytes,
          ),
        ),
        'image/png',
      );
    },
  );
}

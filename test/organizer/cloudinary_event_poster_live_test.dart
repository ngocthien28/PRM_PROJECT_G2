import 'dart:io';

import 'package:campushub/features/organizer_events/data/cloudinary_event_poster_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'poster_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'opt-in: uploads a synthetic 2x2 PNG and reads the real Cloudinary delivery URL',
    () async {
      // Only this explicit opt-in network test bypasses Flutter's fake HTTP
      // client. Unit/widget tests continue using their injected clients.
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousOverrides);
      final service = CloudinaryEventPosterService();
      addTearDown(service.close);
      final poster = await service.upload(
        'uc040-cloudinary-smoke',
        posterSelection(),
      );
      expect(
        poster.url,
        startsWith('https://res.cloudinary.com/djznx3z7o/image/upload/'),
      );
      final response = await http.get(Uri.parse(poster.url));
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], startsWith('image/'));
      expect(response.bodyBytes, isNotEmpty);
      // This preset may not return a token. Never try privileged deletion without
      // one; the small diagnostic asset can be removed via the Cloudinary console.
      if (poster.deleteToken != null) await service.delete(poster);
    },
    skip: !const bool.fromEnvironment('RUN_CLOUDINARY_POSTER_SMOKE'),
  );
}

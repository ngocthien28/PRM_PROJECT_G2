import 'dart:convert';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/data/emulator_event_poster_service.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'poster_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bucket = 'demo-campushub.appspot.com';
  test(
    'Windows emulator media upload includes user auth and returns actual metadata URL',
    () async {
      final progress = <double?>[];
      late String storedPath;
      final service = EmulatorEventPosterService(
        bucket: bucket,
        idToken: () async => 'test-user-token',
        onProgress: progress.add,
        client: MockClient((request) async {
          expect(request.url.host, '127.0.0.1');
          expect(request.url.port, 9199);
          expect(request.headers['Authorization'], 'Bearer test-user-token');
          if (request.method == 'POST') {
            expect(request.headers['Content-Type'], 'image/png');
            expect(request.bodyBytes, posterPng);
            storedPath = request.url.queryParameters['name']!;
            expect(storedPath, startsWith('events/event-1/'));
            return http.Response(
              jsonEncode({
                'bucket': bucket,
                'name': storedPath,
                'downloadTokens': 'real-download-token',
              }),
              200,
            );
          }
          expect(request.method, 'DELETE');
          expect(request.url.pathSegments.last, storedPath);
          return http.Response('', 204);
        }),
      );
      addTearDown(service.close);
      final uploaded = await service.upload('event-1', posterSelection());
      expect(uploaded.path, storedPath);
      final url = Uri.parse(uploaded.url);
      expect(url.pathSegments.last, storedPath);
      expect(url.queryParameters['token'], 'real-download-token');
      expect(uploaded.url, contains('events%2Fevent-1%2F'));
      expect(progress, [0.0, 1.0, null]);
      await service.delete(uploaded);
    },
  );
  test(
    'Rules rejection remains an error and does not return an uploaded poster',
    () async {
      final service = EmulatorEventPosterService(
        bucket: bucket,
        idToken: () async => 'test-user-token',
        client: MockClient(
          (_) async => http.Response('{"error":"denied"}', 403),
        ),
      );
      addTearDown(service.close);
      await expectLater(
        service.upload('event-1', posterSelection()),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
    },
  );
  test('no signed-in user prevents any HTTP upload', () async {
    var calls = 0;
    final service = EmulatorEventPosterService(
      bucket: bucket,
      idToken: () async => null,
      client: MockClient((_) async {
        calls++;
        return http.Response('', 200);
      }),
    );
    addTearDown(service.close);
    await expectLater(
      service.upload('event-1', posterSelection()),
      throwsA(
        isA<AppException>().having((e) => e.code, 'code', 'unauthenticated'),
      ),
    );
    expect(calls, 0);
  });
  test('invalid metadata cannot report upload success', () async {
    final service = EmulatorEventPosterService(
      bucket: bucket,
      idToken: () async => 'test-user-token',
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(service.close);
    await expectLater(
      service.upload('event-1', posterSelection()),
      throwsA(isA<AppException>()),
    );
  });
  test(
    'transport is constrained to loopback demo storage and valid poster paths',
    () async {
      expect(
        () => EmulatorEventPosterService(
          bucket: bucket,
          host: 'storage.googleapis.com',
          idToken: () async => null,
        ),
        throwsArgumentError,
      );
      expect(
        () => EmulatorEventPosterService(
          bucket: 'production.appspot.com',
          idToken: () async => null,
        ),
        throwsArgumentError,
      );
      final service = EmulatorEventPosterService(
        bucket: bucket,
        idToken: () async => 'test-user-token',
        client: MockClient((_) async => throw StateError('must not request')),
      );
      addTearDown(service.close);
      await expectLater(
        service.delete(const UploadedEventPoster(path: '../other', url: '')),
        throwsA(isA<AppException>()),
      );
    },
  );
}

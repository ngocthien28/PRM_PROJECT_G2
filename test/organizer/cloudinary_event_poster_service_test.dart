import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/data/cloudinary_event_poster_service.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_poster_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'poster_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  http.StreamedResponse response(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
      );
  Map<String, dynamic> uploaded(
    http.BaseRequest request, {
    String prefix = '',
  }) {
    final id =
        '$prefix${(request as http.MultipartRequest).fields['public_id']}';
    return {
      'public_id': id,
      'resource_type': 'image',
      'format': 'png',
      'secure_url':
          'https://res.cloudinary.com/djznx3z7o/image/upload/v123/$id.png',
    };
  }

  test(
    'production provider uses Cloudinary without initializing Firebase Storage',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(eventPosterServiceProvider),
        isA<CloudinaryEventPosterService>(),
      );
    },
  );
  test(
    'uploads validated bytes and MIME with the existing preset and a safe event ID',
    () async {
      final progress = <double?>[];
      late http.MultipartRequest sent;
      final service = CloudinaryEventPosterService(
        onProgress: progress.add,
        client: MockClient.streaming((request, body) async {
          sent = request as http.MultipartRequest;
          final bytes = await body.toBytes();
          expect(latin1.decode(bytes), contains('content-type: image/png'));
          expect(sent.files.single.filename, 'poster.png');
          return response(uploaded(request));
        }),
      );
      final result = await service.upload(
        'event-1',
        posterSelection(name: '../../untrusted.png'),
      );
      expect(
        sent.url.toString(),
        'https://api.cloudinary.com/v1_1/djznx3z7o/image/upload',
      );
      expect(sent.fields['upload_preset'], 'campushub_club_logos_unsigned');
      expect(
        sent.fields['public_id'],
        matches(r'^campushub/event_posters/event-1/[a-f0-9-]+$'),
      );
      expect(sent.followRedirects, isFalse);
      expect(sent.fields.keys, isNot(contains('api_secret')));
      expect(result.url, contains('/campushub/event_posters/event-1/'));
      expect(result.path, sent.fields['public_id']);
      expect(progress.first, 0);
      expect(progress, contains(0.99));
      expect(progress[progress.length - 2], 1);
      expect(progress.last, isNull);
    },
  );
  test('accepts the existing preset in fixed-folder mode', () async {
    final service = CloudinaryEventPosterService(
      client: MockClient.streaming((request, body) async {
        await body.drain<void>();
        return response(uploaded(request, prefix: 'campushub/club_logos/'));
      }),
    );
    expect(
      (await service.upload('e1', posterSelection())).path,
      startsWith('campushub/club_logos/campushub/event_posters/e1/'),
    );
  });
  test('rejects invalid content before making any HTTP request', () async {
    var calls = 0;
    final service = CloudinaryEventPosterService(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      service.upload('e1', posterSelection(bytes: Uint8List(4))),
      throwsA(isA<AppException>()),
    );
    expect(calls, 0);
  });
  for (final status in [400, 401, 403, 420, 429, 500]) {
    test('HTTP $status never produces a fake URL or success', () async {
      final progress = <double?>[];
      final service = CloudinaryEventPosterService(
        onProgress: progress.add,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'message': status == 400
                    ? 'Upload preset not found'
                    : 'Rejected',
              },
            }),
            status,
          ),
        ),
      );
      await expectLater(
        service.upload('e1', posterSelection()),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'poster-upload-failed',
          ),
        ),
      );
      expect(progress.last, isNull);
    });
  }
  test('network failure keeps the original cause and permits retry', () async {
    var calls = 0;
    final service = CloudinaryEventPosterService(
      client: MockClient.streaming((request, body) async {
        await body.drain<void>();
        calls++;
        if (calls == 1) throw http.ClientException('offline');
        return response(uploaded(request));
      }),
    );
    await expectLater(
      service.upload('e1', posterSelection()),
      throwsA(
        isA<AppException>().having(
          (e) => e.cause,
          'cause',
          isA<http.ClientException>(),
        ),
      ),
    );
    expect(
      (await service.upload('e1', posterSelection())).url,
      startsWith('https://res.cloudinary.com/'),
    );
  });
  test(
    'timeout aborts the pending request and clears upload progress',
    () async {
      final progress = <double?>[];
      final cancelled = Completer<void>();
      final service = CloudinaryEventPosterService(
        onProgress: progress.add,
        requestTimeout: const Duration(milliseconds: 20),
        client: MockClient.streaming((request, body) async {
          await body.drain<void>();
          await (request as http.Abortable).abortTrigger;
          cancelled.complete();
          throw http.RequestAbortedException(request.url);
        }),
      );
      await expectLater(
        service.upload('e1', posterSelection()),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
      await cancelled.future;
      expect(progress.last, isNull);
    },
  );
  for (final field in [
    'host',
    'cloud',
    'public_id',
    'resource_type',
    'format',
    'query',
  ]) {
    test('rejects an unexpected $field in the upload response', () async {
      final service = CloudinaryEventPosterService(
        client: MockClient.streaming((request, body) async {
          await body.drain<void>();
          final result = uploaded(request);
          switch (field) {
            case 'host':
              result['secure_url'] = (result['secure_url'] as String)
                  .replaceFirst('res.cloudinary.com', 'example.com');
            case 'cloud':
              result['secure_url'] = (result['secure_url'] as String)
                  .replaceFirst('djznx3z7o', 'other');
            case 'public_id':
              result['public_id'] = 'campushub/event_posters/other/file';
            case 'resource_type':
              result['resource_type'] = 'raw';
            case 'format':
              result['format'] = 'svg';
            case 'query':
              result['secure_url'] = '${result['secure_url']}?untrusted=true';
          }
          return response(result);
        }),
      );
      await expectLater(
        service.upload('e1', posterSelection()),
        throwsA(isA<AppException>()),
      );
    });
  }
  test(
    'rejects malformed JSON rather than saving local or fake URLs',
    () async {
      final service = CloudinaryEventPosterService(
        client: MockClient((_) async => http.Response('not JSON', 200)),
      );
      await expectLater(
        service.upload('e1', posterSelection()),
        throwsA(isA<AppException>()),
      );
    },
  );
  test(
    'cleanup uses only the returned deletion token, never API secrets or arbitrary public IDs',
    () async {
      final calls = <http.Request>[];
      final service = CloudinaryEventPosterService(
        client: MockClient((request) async {
          calls.add(request);
          return http.Response('{"result":"ok"}', 200);
        }),
      );
      // The token is a test capability, not a real credential.
      await service.delete(
        const UploadedEventPoster(
          path: 'campushub/event_posters/e1/new',
          url:
              'https://res.cloudinary.com/djznx3z7o/image/upload/v123/campushub/event_posters/e1/new.png',
          deleteToken: 'test-capability',
        ),
      );
      expect(
        calls.single.url.toString(),
        'https://api.cloudinary.com/v1_1/djznx3z7o/delete_by_token',
      );
      expect(calls.single.bodyFields, {'token': 'test-capability'});
    },
  );
  test(
    'cleanup without a token never attempts privileged or arbitrary deletion',
    () async {
      var requests = 0;
      final service = CloudinaryEventPosterService(
        client: MockClient((_) async {
          requests++;
          return http.Response('{"result":"ok"}', 200);
        }),
      );
      await expectLater(
        service.delete(
          const UploadedEventPoster(
            path: 'campushub/event_posters/e1/new',
            url: 'https://example.invalid/new.png',
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'poster-cleanup-unavailable',
          ),
        ),
      );
      expect(requests, 0);
    },
  );
  test(
    'expired or rejected cleanup token is reported without fake success',
    () async {
      final service = CloudinaryEventPosterService(
        client: MockClient(
          (_) async => http.Response('{"result":"not found"}', 400),
        ),
      );
      await expectLater(
        service.delete(
          const UploadedEventPoster(
            path: 'campushub/event_posters/e1/new',
            url: 'https://example.invalid/new.png',
            deleteToken: 'expired-test-token',
          ),
        ),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'poster-cleanup-failed',
          ),
        ),
      );
    },
  );
}

import 'dart:async';
import 'dart:typed_data';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/organizer_events/data/event_poster_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'poster_fixtures.dart';

class MockStorage extends Mock implements FirebaseStorage {}

class MockReference extends Mock implements Reference {}

class MockSnapshot extends Mock implements TaskSnapshot {}

class TestUploadTask extends Fake implements UploadTask {
  TestUploadTask(this.completion, this.events);
  final Future<TaskSnapshot> completion;
  final Stream<TaskSnapshot> events;
  @override
  Stream<TaskSnapshot> get snapshotEvents => events;
  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => completion.then(onValue, onError: onError);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockStorage storage;
  late MockReference reference;
  late MockSnapshot snapshot;
  late FirebaseEventPosterService service;
  late List<double?> progress;
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
  });
  setUp(() {
    storage = MockStorage();
    reference = MockReference();
    snapshot = MockSnapshot();
    progress = [];
    service = FirebaseEventPosterService(storage, onProgress: progress.add);
    when(() => storage.ref(any())).thenReturn(reference);
    when(() => reference.fullPath).thenReturn('events/e1/generated.png');
    when(() => reference.bucket).thenReturn('test-bucket');
    when(
      () => reference.getDownloadURL(),
    ).thenAnswer((_) async => 'https://example.test/download');
    when(() => reference.delete()).thenAnswer((_) async {});
    when(() => snapshot.totalBytes).thenReturn(100);
    when(() => snapshot.bytesTransferred).thenReturn(50);
    when(() => reference.putData(any(), any())).thenAnswer(
      (_) => TestUploadTask(
        Future<TaskSnapshot>.delayed(
          const Duration(milliseconds: 10),
          () => snapshot,
        ),
        Stream.value(snapshot),
      ),
    );
  });
  test(
    'uploads actual bytes with verified MIME and a generated event path',
    () async {
      final result = await service.upload(
        'e1',
        posterSelection(name: '../../raw-name.png'),
      );
      final path =
          verify(() => storage.ref(captureAny())).captured.single as String;
      expect(path, matches(r'^events/e1/[a-f0-9-]+\.png$'));
      final args = verify(
        () => reference.putData(captureAny(), captureAny()),
      ).captured;
      expect(args[0], posterPng);
      expect((args[1] as SettableMetadata).contentType, 'image/png');
      expect(result.url, 'https://example.test/download');
      expect(progress, contains(0.5));
      expect(progress.first, 0);
      expect(progress.last, isNull);
    },
  );
  test('invalid content never reaches Firebase Storage', () async {
    await expectLater(
      service.upload('e1', posterSelection(bytes: Uint8List(3))),
      throwsA(isA<AppException>()),
    );
    verifyNever(() => storage.ref(any()));
  });
  for (final code in ['unauthorized', 'retry-limit-exceeded', 'canceled']) {
    test(
      'maps $code to a readable failure and does not return a fake URL',
      () async {
        when(() => reference.putData(any(), any())).thenAnswer(
          (_) => TestUploadTask(
            Future<TaskSnapshot>.error(
              FirebaseException(plugin: 'firebase_storage', code: code),
            ),
            const Stream.empty(),
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
        verifyNever(() => reference.getDownloadURL());
        expect(progress.last, isNull);
      },
    );
  }
  test('URL lookup failure removes the unattached uploaded file', () async {
    when(
      () => reference.getDownloadURL(),
    ).thenThrow(FirebaseException(plugin: 'firebase_storage', code: 'unknown'));
    await expectLater(
      service.upload('e1', posterSelection()),
      throwsA(isA<AppException>()),
    );
    verify(() => reference.delete()).called(1);
  });
  for (final code in [
    'bucket-not-found',
    'storage/bucket-not-found',
    'project-not-found',
    'no-default-bucket',
  ]) {
    test(
      '$code explains missing storage configuration rather than a network failure',
      () async {
        when(
          () => reference.putData(any(), any()),
        ).thenThrow(FirebaseException(plugin: 'firebase_storage', code: code));
        await expectLater(
          service.upload('e1', posterSelection()),
          throwsA(
            isA<AppException>()
                .having((e) => e.message, 'message', contains('not configured'))
                .having(
                  (e) => e.cause,
                  'original error',
                  isA<FirebaseException>(),
                ),
          ),
        );
        verifyNever(() => reference.delete());
      },
    );
  }
  test(
    'unknown failures do not assert that the network is the cause',
    () async {
      when(() => reference.putData(any(), any())).thenThrow(
        FirebaseException(plugin: 'firebase_storage', code: 'unknown'),
      );
      await expectLater(
        service.upload('e1', posterSelection()),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            isNot(contains('connection')),
          ),
        ),
      );
      verifyNever(() => reference.delete());
    },
  );
}

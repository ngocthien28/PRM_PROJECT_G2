import 'dart:async';

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/events/data/event_repository_impl.dart';
import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../auth/auth_fakes.dart';

class _Firestore extends Mock implements FirebaseFirestore {}

// Test-only mocktail doubles inject native write/read failures and delays.
// ignore: subtype_of_sealed_class
class _Collection extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

// ignore: subtype_of_sealed_class
class _Document extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

void main() {
  final now = DateTime.utc(2030, 1, 1);
  final organizer = testUser(uid: 'organizer-1', role: UserRole.organizer);
  EventFormInput input() => EventFormInput(
    title: ' Retry safe event ',
    description: ' A workshop with enough details for the shared contract. ',
    category: 'technology',
    locationName: ' Hall A ',
    startAt: now.add(const Duration(days: 1)),
    endAt: now.add(const Duration(days: 1, hours: 2)),
    capacity: 80,
  );
  late _Firestore firestore;
  late _Collection collection;
  late _Document document;
  late FakeFirebaseFirestore store;
  late EventRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(const GetOptions(source: Source.server));
  });
  setUp(() {
    firestore = _Firestore();
    collection = _Collection();
    document = _Document();
    store = FakeFirebaseFirestore();
    repository = EventRepositoryImpl(
      firestore: firestore,
      now: () => now,
      requestTimeout: const Duration(milliseconds: 50),
    );
    when(() => firestore.collection('events')).thenReturn(collection);
    when(() => collection.doc()).thenReturn(document);
    when(() => document.id).thenReturn('attempt-1');
    when(
      () => document.get(any()),
    ).thenAnswer((_) => store.collection('events').doc('attempt-1').get());
  });

  test(
    'timeout retry reuses the outstanding write and never creates a second document',
    () async {
      final writeGate = Completer<void>();
      when(() => document.set(any())).thenAnswer((invocation) async {
        await writeGate.future;
        await store
            .collection('events')
            .doc('attempt-1')
            .set(invocation.positionalArguments.first as Map<String, dynamic>);
      });
      await expectLater(
        repository.createEvent(input: input(), actor: organizer),
        throwsA(
          isA<AppException>().having((e) => e.code, 'code', 'event-timeout'),
        ),
      );
      writeGate.complete();
      // A new input object with unchanged values still identifies the same attempt.
      final created = await repository.createEvent(
        input: input(),
        actor: organizer,
      );
      expect(created.id, 'attempt-1');
      expect(created.createdAt.isUtc, isTrue);
      expect(created.updatedAt.isUtc, isTrue);
      expect(created.registeredCount, 0);
      expect(created.checkedInCount, 0);
      expect(created.title, 'Retry safe event');
      expect((await store.collection('events').get()).docs, hasLength(1));
      verify(() => document.set(any())).called(1);
    },
  );

  test(
    'read-back failure retries confirmation without overwriting the event',
    () async {
      when(() => document.set(any())).thenAnswer(
        (invocation) => store
            .collection('events')
            .doc('attempt-1')
            .set(invocation.positionalArguments.first as Map<String, dynamic>),
      );
      var reads = 0;
      when(() => document.get(any())).thenAnswer((_) {
        if (reads++ == 0) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          );
        }
        return store.collection('events').doc('attempt-1').get();
      });
      await expectLater(
        repository.createEvent(input: input(), actor: organizer),
        throwsA(isA<AppException>()),
      );
      await store.collection('events').doc('attempt-1').update({
        'registeredCount': 1,
      });
      final confirmed = await repository.createEvent(
        input: input(),
        actor: organizer,
      );
      expect(confirmed.registeredCount, 1);
      verify(() => document.set(any())).called(1);
    },
  );

  test(
    'permission-denied does not report success and permits a new attempt',
    () async {
      var writes = 0;
      when(() => document.set(any())).thenAnswer((invocation) async {
        if (writes++ == 0) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          );
        }
        await store
            .collection('events')
            .doc('attempt-1')
            .set(invocation.positionalArguments.first as Map<String, dynamic>);
      });
      await expectLater(
        repository.createEvent(input: input(), actor: organizer),
        throwsA(
          isA<AppException>().having(
            (e) => e.code,
            'code',
            'permission-denied',
          ),
        ),
      );
      expect((await store.collection('events').get()).docs, isEmpty);
      expect(
        (await repository.createEvent(input: input(), actor: organizer)).id,
        'attempt-1',
      );
    },
  );

  test('invalid data and student requests never allocate a document', () async {
    await expectLater(
      repository.createEvent(
        input: input(),
        actor: testUser(role: UserRole.student),
      ),
      throwsA(isA<AppException>()),
    );
    repository = EventRepositoryImpl(
      firestore: firestore,
      now: () => input().startAt,
    );
    await expectLater(
      repository.createEvent(input: input(), actor: organizer),
      throwsA(isA<AppException>()),
    );
    verifyNever(() => collection.doc());
  });
}

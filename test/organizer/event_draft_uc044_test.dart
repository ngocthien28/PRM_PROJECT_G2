import 'dart:async';
import 'dart:io';
import 'package:campushub/features/organizer_events/data/event_draft_repository.dart';
import 'package:campushub/features/organizer_events/data/models/event_draft.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/event_draft_controller.dart';
import 'package:campushub/local/dao/event_draft_dao.dart';
import 'package:campushub/local/db_migrations.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../auth/auth_fakes.dart';

Map<String, dynamic> fields([String title = '']) => {
  'title': title,
  'description': '',
  'category': '',
  'locationName': '',
  'capacity': 'not an integer',
  'startAt': DateTime.utc(2030).toIso8601String(),
  'endAt': DateTime.utc(2029).toIso8601String(),
  'posterSelected': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;
  late EventDraftDao dao;
  late EventDraftRepository repository;
  late Directory directory;
  var actor = testUser(uid: 'A', role: UserRole.organizer);
  Future<Database> open() => databaseFactoryFfi.openDatabase(
    '${directory.path}/drafts.db',
    options: OpenDatabaseOptions(
      version: DbMigrations.currentVersion,
      onCreate: DbMigrations.onCreate,
      onUpgrade: DbMigrations.onUpgrade,
    ),
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('draft_uc044_');
    db = await open();
    dao = EventDraftDao(db);
    actor = testUser(uid: 'A', role: UserRole.organizer);
    repository = EventDraftRepository(
      dao: () async => dao,
      currentActor: () => actor,
    );
  });
  tearDown(() async {
    if (db.isOpen) await db.close();
    await directory.delete(recursive: true);
  });
  EventDraft draft([String title = '']) => EventDraft(
    id: 'request-1',
    organizerId: 'A',
    fields: fields(title),
    createdAt: DateTime.utc(2030),
    updatedAt: DateTime.utc(2030, 1, 2),
  );

  test(
    'incomplete input and UTC dates survive connection close/reopen',
    () async {
      await repository.saveDraft(draft());
      await db.close();
      db = await open();
      dao = EventDraftDao(db);
      final restored = (await repository.getDraft())!;
      expect(restored.fields, fields());
      expect(restored.createdAt, DateTime.utc(2030));
      expect(restored.updatedAt, DateTime.utc(2030, 1, 2));
      expect(restored.id, 'request-1');
      expect(await repository.hasDraft(), isTrue);
    },
  );
  test('upsert does not duplicate; delete is scoped and idempotent', () async {
    await repository.saveDraft(draft());
    await repository.saveDraft(draft('changed'));
    expect(await db.query('event_drafts'), hasLength(1));
    expect((await repository.getDraft())!.fields['title'], 'changed');
    await repository.deleteDraft();
    await repository.deleteDraft();
    expect(await repository.hasDraft(), isFalse);
  });
  test('accounts and roles cannot access another organizer draft', () async {
    await repository.saveDraft(draft());
    actor = testUser(uid: 'B', role: UserRole.organizer);
    expect(await repository.getDraft(), isNull);
    await expectLater(repository.saveDraft(draft()), throwsException);
    await repository.deleteDraft();
    expect(await dao.hasDraft('A'), isTrue);
    actor = testUser(uid: 'A', role: UserRole.student);
    await expectLater(repository.getDraft(), throwsException);
  });
  test('database failure is a recoverable application error', () async {
    await db.close();
    await expectLater(repository.getDraft(), throwsException);
  });
  test(
    'cleanup from an old account cannot delete the new account draft',
    () async {
      final controller = EventDraftController(
        repository: repository,
        organizerId: 'A',
      );
      await repository.saveDraft(draft('A saved'));
      actor = testUser(uid: 'B', role: UserRole.organizer);
      await repository.saveDraft(
        EventDraft(
          id: 'B-id',
          organizerId: 'B',
          fields: fields('B saved'),
          createdAt: DateTime.utc(2030),
          updatedAt: DateTime.utc(2030),
        ),
      );
      expect(await controller.clear(submitted: true), isFalse);
      expect((await repository.getDraft())!.fields['title'], 'B saved');
      expect(await dao.hasDraft('A'), isTrue);
      controller.dispose();
    },
  );
  test(
    'an older failed write cannot overwrite a newer queued successful write',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      final flaky = EventDraftRepository(
        dao: () async {
          calls++;
          if (calls == 1) {
            await gate.future;
            throw StateError('old write failed');
          }
          return dao;
        },
        currentActor: () => actor,
      );
      final controller = EventDraftController(
        repository: flaky,
        organizerId: 'A',
      );
      controller.changed(fields('old'));
      final first = controller.flush();
      controller.changed(fields('latest'));
      final second = controller.flush();
      gate.complete();
      await first;
      await second;
      controller.dispose();
      await controller.flush();
      expect((await repository.getDraft())!.fields['title'], 'latest');
      expect(calls, 2);
    },
  );
  test(
    'corrupt payload is reported and preserved for explicit discard',
    () async {
      await repository.saveDraft(draft());
      await db.update('event_drafts', {'payload': '{broken'});
      await expectLater(repository.getDraft(), throwsException);
      expect(await repository.hasDraft(), isTrue);
      await repository.deleteDraft();
      expect(await repository.hasDraft(), isFalse);
    },
  );
  test('v3 migration preserves unrelated cached data', () async {
    await db.close();
    final oldPath = '${directory.path}/old.db';
    var old = await databaseFactoryFfi.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE cached_events (id TEXT PRIMARY KEY)');
          await db.insert('cached_events', {'id': 'keep'});
        },
      ),
    );
    await old.close();
    old = await databaseFactoryFfi.openDatabase(
      oldPath,
      options: OpenDatabaseOptions(
        version: 4,
        onUpgrade: DbMigrations.onUpgrade,
      ),
    );
    expect((await old.query('cached_events')).single['id'], 'keep');
    expect(await EventDraftDao(old).hasDraft('A'), isFalse);
    await old.close();
  });
  testWidgets(
    'debounce saves latest raw input once, and navigation flushes pending data',
    (tester) async {
      final controller = EventDraftController(
        repository: repository,
        organizerId: 'A',
      );
      controller.changed(fields('one'));
      await tester.pump(const Duration(milliseconds: 400));
      controller.changed(fields('two'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(await tester.runAsync(repository.hasDraft), isFalse);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(controller.flush);
      expect(
        (await tester.runAsync(repository.getDraft))!.fields['title'],
        'two',
      );
      controller.changed(fields('leaving'));
      controller.dispose();
      await tester.runAsync(controller.flush);
      expect(
        (await tester.runAsync(repository.getDraft))!.fields['title'],
        'leaving',
      );
    },
  );
  test('late restoration cannot overwrite new input', () async {
    final gate = Completer<EventDraftDao>();
    final delayed = EventDraftRepository(
      dao: () => gate.future,
      currentActor: () => actor,
    );
    final controller = EventDraftController(
      repository: delayed,
      organizerId: 'A',
    );
    await repository.saveDraft(draft('old'));
    final loading = controller.restore();
    controller.changed(fields('new'));
    gate.complete(dao);
    expect(await loading, isNull);
    await controller.flush();
    expect((await repository.getDraft())!.fields['title'], 'new');
    controller.dispose();
  });
  test(
    'success/discard waits for pending writes and prevents resurrection',
    () async {
      final controller = EventDraftController(
        repository: repository,
        organizerId: 'A',
      );
      controller.changed(fields('save'));
      final writing = controller.flush();
      expect(await controller.clear(submitted: true), isTrue);
      await writing;
      controller.changed(fields('late'));
      controller.dispose();
      await controller.flush();
      expect(await repository.hasDraft(), isFalse);
    },
  );
  test('failed save can retry without losing the latest revision', () async {
    var fail = true;
    final flaky = EventDraftRepository(
      dao: () async {
        if (fail) throw StateError('disk error');
        return dao;
      },
      currentActor: () => actor,
    );
    final controller = EventDraftController(
      repository: flaky,
      organizerId: 'A',
    );
    controller.changed(fields('latest'));
    await controller.flush();
    expect(controller.message, contains('retry'));
    fail = false;
    await controller.flush();
    expect((await repository.getDraft())!.fields['title'], 'latest');
    controller.dispose();
  });
}

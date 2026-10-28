import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/features/registration/data/registration_repository_impl.dart';
import 'package:campushub/local/app_database.dart';
import 'package:campushub/local/dao/ticket_dao.dart';
import 'package:campushub/local/db_migrations.dart';
import 'package:campushub/shared/enums/registration_status.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../events/event_fakes.dart';
import 'registration_fakes.dart';

class _Database extends Mock implements AppDatabase {}

class _Unavailable extends FakeFirebaseFirestore {
  _Unavailable(this.code);
  final String code;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      throw FirebaseException(plugin: 'cloud_firestore', code: code);
}

void main() {
  late Database database;
  late _Database provider;
  late TicketDao dao;
  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DbMigrations.currentVersion,
        onCreate: DbMigrations.onCreate,
      ),
    );
    provider = _Database();
    when(() => provider.database).thenAnswer((_) async => database);
    dao = TicketDao(provider);
  });
  tearDown(() => database.close());

  test(
    'UC-060 SQLite round trip keeps status, timestamps, token and owner',
    () async {
      for (final status in RegistrationStatus.values) {
        final reg = testRegistration(
          id: status.name,
          status: status,
          checkedInAt: status == RegistrationStatus.checkedIn
              ? DateTime.utc(2030, 5, 2)
              : null,
          cancelledAt: status == RegistrationStatus.cancelled
              ? DateTime.utc(2030, 5, 2)
              : null,
        );
        await dao.saveTicket(
          registration: reg,
          eventTitle: 'Cached workshop',
          startAt: DateTime.utc(2030, 6),
        );
        final cached = await TicketDao(provider).getTicket(reg.id);
        final restored = cached!.toRegistrationModel();
        expect(restored.status, status);
        expect(restored.registeredAt, reg.registeredAt);
        expect(restored.checkedInAt, reg.checkedInAt);
        expect(restored.cancelledAt, reg.cancelledAt);
        expect(restored.encodedQr, reg.encodedQr);
        expect(restored.isFromCache, isTrue);
        expect(cached.eventTitle, 'Cached workshop');
      }
      expect(await dao.getMyTickets('another-user'), isEmpty);
    },
  );

  test('UC-060 v4 migration keeps existing tickets readable', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    addTearDown(legacy.close);
    await legacy.execute(
      'CREATE TABLE offline_tickets (registration_id TEXT PRIMARY KEY, user_id TEXT, event_id TEXT, qr_token TEXT, event_title TEXT, start_at INTEGER, updated_at INTEGER)',
    );
    await legacy.insert('offline_tickets', {
      'registration_id': 'old',
      'user_id': 'student',
      'event_id': 'event',
      'qr_token': 'token',
      'event_title': 'Old event',
      'start_at': 1,
      'updated_at': 2,
    });
    await DbMigrations.onUpgrade(legacy, 4, 5);
    final record = OfflineTicketRecord.fromMap(
      (await legacy.query('offline_tickets')).single,
    );
    expect(record.toRegistrationModel().status, RegistrationStatus.registered);
    expect(record.qrToken, 'token');
  });

  test(
    'UC-060 reconnect reconciles check-in, cancellation and server deletion',
    () async {
      final remote = FakeFirebaseFirestore();
      final reg = testRegistration(id: 'event-1_user-1');
      await remote.collection('events').doc('event-1').set(testEvent().toMap());
      final document = remote.collection('registrations').doc(reg.id);
      await document.set(reg.toMap());
      final online = RegistrationRepositoryImpl(remote, dao);
      final offline = RegistrationRepositoryImpl(
        _Unavailable('unavailable'),
        dao,
      );
      await online.getMyRegistrations(reg.userId);
      expect(
        (await offline.getMyRegistrations(reg.userId)).single.isActive,
        isTrue,
      );
      await document.update({
        'status': 'checkedIn',
        'checkedInAt': Timestamp.fromDate(DateTime.utc(2030, 5, 2)),
      });
      expect(
        (await online.getRegistration(reg.eventId, reg.userId))!.isCheckedIn,
        isTrue,
      );
      expect(
        (await offline.getMyRegistrations(reg.userId)).single.isCheckedIn,
        isTrue,
      );
      expect((await dao.getTicket(reg.id))!.eventTitle, testEvent().title);
      await document.update({'status': 'cancelled'});
      await online.getMyRegistrations(reg.userId);
      expect(
        (await offline.getMyRegistrations(reg.userId)).single.isCancelled,
        isTrue,
      );
      await document.delete();
      expect(await online.getMyRegistrations(reg.userId), isEmpty);
      expect(await dao.getMyTickets(reg.userId), isEmpty);
    },
  );

  test(
    'UC-060 permission errors and empty offline cache do not fabricate tickets',
    () async {
      final reg = testRegistration();
      await dao.saveTicket(
        registration: reg,
        eventTitle: 'Private',
        startAt: DateTime.utc(2030),
      );
      final denied = RegistrationRepositoryImpl(
        _Unavailable('permission-denied'),
        dao,
      );
      await expectLater(
        denied.getMyRegistrations(reg.userId),
        throwsA(isA<AppException>()),
      );
      final offline = RegistrationRepositoryImpl(
        _Unavailable('unavailable'),
        dao,
      );
      await expectLater(
        offline.getMyRegistrations('new-user'),
        throwsA(isA<AppException>()),
      );
      when(() => provider.database).thenAnswer((_) async => null);
      expect(await dao.getMyTickets('no-web-tickets'), isEmpty);
    },
  );
}

import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/local/dao/notification_cache_dao.dart';
import 'package:campushub/local/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database database;
  late NotificationCacheDao cache;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DbMigrations.currentVersion,
        onCreate: DbMigrations.onCreate,
      ),
    );
    cache = NotificationCacheDao(openDatabase: () async => database);
  });

  tearDown(() => database.close());

  test(
    'cache remains account-scoped and preserves notification data',
    () async {
      await cache.replace('student-a', [_notification('n1', 'student-a')]);
      await cache.replace('student-b', [_notification('n2', 'student-b')]);

      expect((await cache.load('student-a')).single.id, 'n1');
      expect((await cache.load('student-b')).single.id, 'n2');
      expect((await cache.load('missing')), isEmpty);
    },
  );

  test('markRead persists across a new DAO instance', () async {
    await cache.replace('student-a', [_notification('n1', 'student-a')]);
    await cache.markRead('n1');

    final reopened = NotificationCacheDao(openDatabase: () async => database);
    expect((await reopened.load('student-a')).single.isRead, true);
  });
}

AppNotification _notification(String id, String userId) => AppNotification(
  id: id,
  userId: userId,
  title: 'Campus update',
  body: 'A useful cached notification.',
  type: 'event',
  referenceId: 'event-1',
  isRead: false,
  createdAt: DateTime.utc(2026, 10, 28, 8),
);

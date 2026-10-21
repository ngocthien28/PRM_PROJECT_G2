import 'dart:io';

import 'package:campushub/local/app_database.dart';
import 'package:campushub/local/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'desktop database persists data without changing the default factory',
    () async {
      final defaultFactory = databaseFactoryOrNull;
      sqfliteFfiInit();
      final factory = databaseFactoryFfi;
      final originalPath = await factory.getDatabasesPath();
      final directory = await Directory.systemTemp.createTemp('campushub_db_');
      final databasePath = p.join(directory.path, 'campushub.db');
      final appDatabase = AppDatabase.instance;
      addTearDown(() async {
        await appDatabase.close();
        await factory.deleteDatabase(databasePath);
        await factory.setDatabasesPath(originalPath);
        await directory.delete();
      });
      await factory.setDatabasesPath(directory.path);

      final db = await appDatabase.database;
      expect(db, isNotNull);
      expect(db!.path, databasePath);
      expect(await db.getVersion(), DbMigrations.currentVersion);
      expect(databaseFactoryOrNull, same(defaultFactory));
      expect(await appDatabase.database, same(db));

      await db.insert('local_profile_cache', {
        'user_id': 'student',
        'cache_key': 'setting:theme',
        'payload': '{"value":"dark"}',
        'updated_at': 1,
      });
      await appDatabase.close();

      final reopened = await appDatabase.database;
      expect(reopened, isNotNull);
      expect(
        (await reopened!.query('local_profile_cache')).single['payload'],
        '{"value":"dark"}',
      );
      expect(databaseFactoryOrNull, same(defaultFactory));
    },
    skip: !(Platform.isWindows || Platform.isLinux || Platform.isMacOS),
  );
}

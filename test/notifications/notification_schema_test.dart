import 'package:campushub/local/db_migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'v1 migration preserves old tables and creates user-isolated cache',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute('CREATE TABLE old_data (id TEXT)');
      await db.insert('old_data', {'id': 'kept'});
      await DbMigrations.onUpgrade(db, 1, 2);
      await DbMigrations.onUpgrade(db, 1, 2);
      for (final uid in ['u1', 'u2']) {
        await db.insert('cached_notifications', {
          'id': 'n1',
          'user_id': uid,
          'payload': '{}',
          'updated_at': 1,
        });
      }
      expect((await db.query('old_data')).single['id'], 'kept');
      expect((await db.query('cached_notifications')).length, 2);
    },
  );
}

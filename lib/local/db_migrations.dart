import 'package:sqflite/sqflite.dart';

import 'local_tables.dart';

/// Database schema initialization and version migrations for CampusHub.
abstract final class DbMigrations {
  static const int currentVersion = 3;

  static Future<void> createNotificationCache(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS cached_notifications (
      id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, id)
    )
  ''');

  static Future<void> onCreate(Database db, int version) async {
    await createNotificationCache(db);
    await createProfileCache(db);
    // 1. cached_events
    await db.execute('''
      CREATE TABLE ${LocalTables.cachedEvents} (
        ${LocalTables.colId} TEXT PRIMARY KEY,
        ${LocalTables.colJson} TEXT NOT NULL,
        ${LocalTables.colUpdatedAt} INTEGER NOT NULL
      )
    ''');

    // 2. offline_tickets
    await db.execute('''
      CREATE TABLE ${LocalTables.offlineTickets} (
        ${LocalTables.colRegistrationId} TEXT PRIMARY KEY,
        ${LocalTables.colUserId} TEXT NOT NULL,
        ${LocalTables.colEventId} TEXT NOT NULL,
        ${LocalTables.colQrToken} TEXT NOT NULL,
        ${LocalTables.colEventTitle} TEXT NOT NULL,
        ${LocalTables.colStartAt} INTEGER NOT NULL,
        ${LocalTables.colUpdatedAt} INTEGER NOT NULL
      )
    ''');

    // 3. recently_viewed
    await db.execute('''
      CREATE TABLE ${LocalTables.recentlyViewed} (
        ${LocalTables.colEventId} TEXT PRIMARY KEY,
        ${LocalTables.colUserId} TEXT NOT NULL,
        ${LocalTables.colViewedAt} INTEGER NOT NULL
      )
    ''');

    // 4. favorite_local
    await db.execute('''
      CREATE TABLE ${LocalTables.favoriteLocal} (
        ${LocalTables.colEventId} TEXT NOT NULL,
        ${LocalTables.colUserId} TEXT NOT NULL,
        ${LocalTables.colIsFavorite} INTEGER NOT NULL,
        ${LocalTables.colUpdatedAt} INTEGER NOT NULL,
        PRIMARY KEY(${LocalTables.colEventId}, ${LocalTables.colUserId})
      )
    ''');
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await createNotificationCache(db);
    if (oldVersion < 3) await createProfileCache(db);
  }

  static Future<void> createProfileCache(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS local_profile_cache (
      user_id TEXT NOT NULL, cache_key TEXT NOT NULL, payload TEXT NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY(user_id, cache_key)
    )
  ''');
}

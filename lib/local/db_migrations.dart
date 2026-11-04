import 'package:sqflite/sqflite.dart';

import 'local_tables.dart';

/// Database schema initialization and version migrations for CampusHub.
abstract final class DbMigrations {
  static const int currentVersion = 5;

  static Future<void> createEventDrafts(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS event_drafts (
      organizer_id TEXT PRIMARY KEY, id TEXT NOT NULL,
      payload TEXT NOT NULL, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');

  static Future<void> createNotificationCache(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS cached_notifications (
      id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      payload TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (user_id, id)
    )
  ''');

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Tạo schema ban đầu, bao gồm local_profile_cache qua createProfileCache.
  /// ROLE: Profile cache schema
  /// CALLED FROM: AppDatabase._initDatabase onCreate.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite.
  static Future<void> onCreate(Database db, int version) async {
    await createNotificationCache(db);
    await createProfileCache(db);
    await createEventDrafts(db);
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
        status TEXT NOT NULL DEFAULT 'registered',
        registered_at INTEGER,
        checked_in_at INTEGER,
        cancelled_at INTEGER,
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

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Khi nâng từ version dưới 3 lên ít nhất 3, tạo local_profile_cache; giữ các migration module khác.
  /// ROLE: Profile cache schema
  /// CALLED FROM: AppDatabase._initDatabase onUpgrade.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite.
  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await createNotificationCache(db);
    }
    if (oldVersion < 3 && newVersion >= 3) await createProfileCache(db);
    if (oldVersion < 4 && newVersion >= 4) await createEventDrafts(db);
    if (oldVersion < 5 && newVersion >= 5) {
      await db.execute(
        "ALTER TABLE offline_tickets ADD COLUMN status TEXT NOT NULL DEFAULT 'registered'",
      );
      for (final column in ['registered_at', 'checked_in_at', 'cancelled_at']) {
        await db.execute(
          'ALTER TABLE offline_tickets ADD COLUMN $column INTEGER',
        );
      }
    }
  }

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Tạo bảng profile/settings khóa ghép user_id/cache_key cùng JSON payload.
  /// ROLE: Profile cache schema
  /// CALLED FROM: DbMigrations.onCreate và onUpgrade.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite.
  static Future<void> createProfileCache(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS local_profile_cache (
      user_id TEXT NOT NULL, cache_key TEXT NOT NULL, payload TEXT NOT NULL,
      updated_at INTEGER NOT NULL, PRIMARY KEY(user_id, cache_key)
    )
  ''');
}

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_migrations.dart';

/// Singleton manager for CampusHub's local SQLite database.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  late final DatabaseFactory _factory = _createDatabaseFactory();

  /// Returns the open [Database] instance, or null if on Web or if initialization fails.
  Future<Database?> get database async {
    if (kIsWeb) {
      // SQLite binary bindings are not available on Flutter Web directly.
      return null;
    }
    if (_db != null && _db!.isOpen) return _db;

    try {
      _db = await _initDatabase();
      return _db;
    } catch (e, stack) {
      debugPrint('AppDatabase initialization failed: $e\n$stack');
      return null;
    }
  }

  DatabaseFactory _createDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      // Keep the desktop factory local instead of replacing sqflite's default.
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await _factory.getDatabasesPath();
    final path = p.join(databasesPath, 'campushub.db');

    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: DbMigrations.currentVersion,
        onCreate: DbMigrations.onCreate,
        onUpgrade: DbMigrations.onUpgrade,
      ),
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

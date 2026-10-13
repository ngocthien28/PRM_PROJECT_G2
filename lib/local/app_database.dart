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
  bool _ffiInitialized = false;

  /// Returns the open [Database] instance, or null if on Web or if initialization fails.
  Future<Database?> get database async {
    if (kIsWeb) {
      // SQLite binary bindings are not available on Flutter Web directly.
      return null;
    }
    if (_db != null && _db!.isOpen) return _db;

    try {
      _initFfiIfNeeded();
      _db = await _initDatabase();
      return _db;
    } catch (e, stack) {
      debugPrint('AppDatabase initialization failed: $e\n$stack');
      return null;
    }
  }

  void _initFfiIfNeeded() {
    if (kIsWeb) return;
    if (!_ffiInitialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _ffiInitialized = true;
    }
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, 'campushub.db');

    return openDatabase(
      path,
      version: DbMigrations.currentVersion,
      onCreate: DbMigrations.onCreate,
      onUpgrade: DbMigrations.onUpgrade,
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

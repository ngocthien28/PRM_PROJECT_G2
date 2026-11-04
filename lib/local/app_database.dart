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
  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Trả SQLite dùng lại; Web hoặc lỗi khởi tạo trả null để cache bỏ qua.
  /// ROLE: SQLite database lifecycle
  /// CALLED FROM: LocalProfileCache._save và _read.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite_common_ffi.
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

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Chọn FFI factory riêng trên desktop và factory mặc định trên mobile.
  /// ROLE: SQLite database lifecycle
  /// CALLED FROM: AppDatabase._factory.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite_common_ffi.
  DatabaseFactory _createDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      // Keep the desktop factory local instead of replacing sqflite's default.
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Mở campushub.db với version và callbacks DbMigrations.
  /// ROLE: SQLite database lifecycle
  /// CALLED FROM: AppDatabase.database.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite_common_ffi.
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

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Đóng database và xóa tham chiếu để lần đọc sau mở lại.
  /// ROLE: SQLite database lifecycle
  /// CALLED FROM: Lifecycle/test database persistence.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, sqflite_common_ffi.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

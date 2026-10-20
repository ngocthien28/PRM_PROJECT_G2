import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_database.dart';
import '../local_tables.dart';

/// Trạng thái favorite lưu cục bộ cho một cặp (eventId, userId).
class FavoriteLocalRecord {
  const FavoriteLocalRecord({
    required this.eventId,
    required this.userId,
    required this.isFavorite,
    required this.updatedAt,
  });

  final String eventId;
  final String userId;
  final bool isFavorite;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
    LocalTables.colEventId: eventId,
    LocalTables.colUserId: userId,
    LocalTables.colIsFavorite: isFavorite ? 1 : 0,
    LocalTables.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
  };

  factory FavoriteLocalRecord.fromMap(Map<String, dynamic> map) =>
      FavoriteLocalRecord(
        eventId: map[LocalTables.colEventId] as String,
        userId: map[LocalTables.colUserId] as String,
        isFavorite: (map[LocalTables.colIsFavorite] as int) == 1,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map[LocalTables.colUpdatedAt] as int,
        ),
      );
}

/// DAO cho bảng [LocalTables.favoriteLocal] — lưu trạng thái yêu thích offline.
class FavoriteLocalDao {
  FavoriteLocalDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  // Web / test fallback in-memory cache
  static final Map<String, bool> _webCache = {};

  bool get _useMemoryCache =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  static String _key(String eventId, String userId) => '$userId:$eventId';

  /// Lưu hoặc cập nhật trạng thái yêu thích cho event.
  Future<void> setFavorite({
    required String eventId,
    required String userId,
    required bool isFavorite,
  }) async {
    _webCache[_key(eventId, userId)] = isFavorite;

    if (_useMemoryCache) return;

    final db = await _db.database;
    if (db == null) return;

    await db.insert(
      LocalTables.favoriteLocal,
      FavoriteLocalRecord(
        eventId: eventId,
        userId: userId,
        isFavorite: isFavorite,
        updatedAt: DateTime.now(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Kiểm tra trạng thái yêu thích cục bộ.
  Future<bool> isFavorite({
    required String eventId,
    required String userId,
  }) async {
    if (_useMemoryCache) {
      return _webCache[_key(eventId, userId)] ?? false;
    }

    final db = await _db.database;
    if (db == null) return _webCache[_key(eventId, userId)] ?? false;

    final rows = await db.query(
      LocalTables.favoriteLocal,
      columns: [LocalTables.colIsFavorite],
      where:
          '${LocalTables.colEventId} = ? AND ${LocalTables.colUserId} = ?',
      whereArgs: [eventId, userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return (rows.first[LocalTables.colIsFavorite] as int) == 1;
  }

  /// Trả về danh sách eventId được đánh dấu yêu thích của user.
  Future<List<String>> getFavoriteEventIds(String userId) async {
    if (_useMemoryCache) {
      return _webCache.entries
          .where((e) => e.key.startsWith('$userId:') && e.value)
          .map((e) => e.key.substring(userId.length + 1))
          .toList();
    }

    final db = await _db.database;
    if (db == null) {
      return _webCache.entries
          .where((e) => e.key.startsWith('$userId:') && e.value)
          .map((e) => e.key.substring(userId.length + 1))
          .toList();
    }

    final rows = await db.query(
      LocalTables.favoriteLocal,
      columns: [LocalTables.colEventId],
      where:
          '${LocalTables.colUserId} = ? AND ${LocalTables.colIsFavorite} = 1',
      whereArgs: [userId],
    );
    return rows
        .map((r) => r[LocalTables.colEventId] as String)
        .toList();
  }

  /// Xóa cache cục bộ theo user (khi logout).
  Future<void> clearForUser(String userId) async {
    _webCache.removeWhere((key, _) => key.startsWith('$userId:'));
    if (_useMemoryCache) return;

    final db = await _db.database;
    if (db == null) return;
    await db.delete(
      LocalTables.favoriteLocal,
      where: '${LocalTables.colUserId} = ?',
      whereArgs: [userId],
    );
  }
}

final favoriteLocalDaoProvider = Provider<FavoriteLocalDao>(
  (_) => FavoriteLocalDao(),
);

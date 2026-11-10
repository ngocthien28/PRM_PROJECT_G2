// Author: ThaiQHCE181542 - Quách Hoàng Thái
// UC-086: Local Data & Responsive - View Recently Viewed Events
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../app_database.dart';
import '../local_tables.dart';

/// Bản ghi lịch sử xem sự kiện gần đây cục bộ (UC-086).
class RecentViewRecord {
  const RecentViewRecord({
    required this.eventId,
    required this.userId,
    required this.viewedAt,
  });

  final String eventId;
  final String userId;
  final DateTime viewedAt;

  Map<String, dynamic> toMap() => {
    LocalTables.colEventId: eventId,
    LocalTables.colUserId: userId,
    LocalTables.colViewedAt: viewedAt.millisecondsSinceEpoch,
  };

  factory RecentViewRecord.fromMap(Map<String, dynamic> map) => RecentViewRecord(
    eventId: map[LocalTables.colEventId] as String,
    userId: map[LocalTables.colUserId] as String,
    viewedAt: DateTime.fromMillisecondsSinceEpoch(
      map[LocalTables.colViewedAt] as int,
    ),
  );
}

/// DAO cho bảng [LocalTables.recentlyViewed] — lưu lịch sử xem sự kiện offline (UC-086).
class RecentViewDao {
  RecentViewDao([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  // In-memory web/test fallback: userId -> Map<eventId, timestamp>
  static final Map<String, Map<String, int>> _webCache = {};

  bool get _useMemoryCache =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  /// Ghi nhận lịch sử xem sự kiện của user.
  Future<void> recordView({
    required String eventId,
    required String userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _webCache.putIfAbsent(userId, () => {})[eventId] = now;

    if (_useMemoryCache) return;

    final db = await _db.database;
    if (db == null) return;

    await db.insert(
      LocalTables.recentlyViewed,
      {
        LocalTables.colEventId: eventId,
        LocalTables.colUserId: userId,
        LocalTables.colViewedAt: now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy danh sách ID các sự kiện đã xem gần đây của user, sắp xếp theo thời gian xem mới nhất.
  Future<List<String>> getRecentlyViewedEventIds({
    required String userId,
    int limit = 10,
  }) async {
    if (_useMemoryCache) {
      final userViews = _webCache[userId] ?? {};
      final entries = userViews.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(limit).map((e) => e.key).toList();
    }

    final db = await _db.database;
    if (db == null) {
      final userViews = _webCache[userId] ?? {};
      final entries = userViews.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return entries.take(limit).map((e) => e.key).toList();
    }

    final rows = await db.query(
      LocalTables.recentlyViewed,
      columns: [LocalTables.colEventId],
      where: '${LocalTables.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${LocalTables.colViewedAt} DESC',
      limit: limit,
    );

    return rows.map((r) => r[LocalTables.colEventId] as String).toList();
  }

  /// Xóa toàn bộ lịch sử xem gần đây của user.
  Future<void> clearForUser(String userId) async {
    _webCache.remove(userId);
    if (_useMemoryCache) return;

    final db = await _db.database;
    if (db == null) return;

    await db.delete(
      LocalTables.recentlyViewed,
      where: '${LocalTables.colUserId} = ?',
      whereArgs: [userId],
    );
  }
}

final recentViewDaoProvider = Provider<RecentViewDao>(
  (_) => RecentViewDao(),
);

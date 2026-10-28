import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../features/notifications/data/models/app_notification.dart';
import '../app_database.dart';
import '../local_tables.dart';

abstract interface class NotificationCache {
  Future<List<AppNotification>> load(String userId);
  Future<void> replace(String userId, List<AppNotification> notifications);
  Future<void> markRead(String notificationId);
}

/// Account-scoped SQLite cache used by the notification inbox on desktop and
/// mobile. Corrupt rows are ignored so a damaged cache never blocks the inbox.
class NotificationCacheDao implements NotificationCache {
  NotificationCacheDao({Future<Database?> Function()? openDatabase})
    : _openDatabase = openDatabase ?? (() => AppDatabase.instance.database);

  final Future<Database?> Function() _openDatabase;
  final Map<String, Map<String, AppNotification>> _memory = {};

  @override
  Future<List<AppNotification>> load(String userId) async {
    final database = await _openDatabase();
    if (database == null) return _memoryItems(userId);

    final rows = await database.query(
      LocalTables.cachedNotifications,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'updated_at DESC',
    );
    final items = <AppNotification>[];
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload'] as String);
        if (payload is! Map<String, dynamic>) continue;
        items.add(AppNotification.fromCacheMap(payload));
      } catch (_) {
        // Ignore a single invalid row and keep the rest of the inbox usable.
      }
    }
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> replace(
    String userId,
    List<AppNotification> notifications,
  ) async {
    _memory[userId] = {for (final item in notifications) item.id: item};
    final database = await _openDatabase();
    if (database == null) return;

    await database.transaction((transaction) async {
      await transaction.delete(
        LocalTables.cachedNotifications,
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      final batch = transaction.batch();
      final updatedAt = DateTime.now().millisecondsSinceEpoch;
      for (final item in notifications) {
        batch.insert(LocalTables.cachedNotifications, {
          'id': item.id,
          'user_id': userId,
          'payload': jsonEncode(item.toCacheMap()),
          'updated_at': updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> markRead(String notificationId) async {
    for (final entries in _memory.values) {
      final item = entries[notificationId];
      if (item != null) entries[notificationId] = item.copyWith(isRead: true);
    }

    final database = await _openDatabase();
    if (database == null) return;
    final rows = await database.query(
      LocalTables.cachedNotifications,
      where: 'id = ?',
      whereArgs: [notificationId],
    );
    for (final row in rows) {
      try {
        final payload = jsonDecode(row['payload'] as String);
        if (payload is! Map<String, dynamic>) continue;
        payload['isRead'] = true;
        await database.update(
          LocalTables.cachedNotifications,
          {
            'payload': jsonEncode(payload),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          where: 'user_id = ? AND id = ?',
          whereArgs: [row['user_id'], notificationId],
        );
      } catch (_) {
        // A later successful refresh replaces invalid rows.
      }
    }
  }

  List<AppNotification> _memoryItems(String userId) {
    final items = _memory[userId]?.values.toList() ?? <AppNotification>[];
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
}

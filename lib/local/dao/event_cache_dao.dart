import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../features/events/data/models/event_model.dart';
import '../app_database.dart';
import '../local_tables.dart';

/// DAO for [LocalTables.cachedEvents] - SQLite event caching and offline fallback.
class EventCacheDao {
  EventCacheDao([AppDatabase? database])
      : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;
  // In-memory cache fallback for web and test environments where SQLite binary is unavailable
  static final Map<String, EventModel> _webCache = {};

  /// Batch insert or replace cached events.
  Future<void> saveEvents(List<EventModel> events) async {
    for (final event in events) {
      _webCache[event.id] = event;
    }
    final db = await _db.database;
    if (db == null) return;

    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final event in events) {
      batch.insert(
        LocalTables.cachedEvents,
        {
          LocalTables.colId: event.id,
          LocalTables.colJson: jsonEncode(event.toJson()),
          LocalTables.colUpdatedAt: now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Insert or replace a single cached event.
  Future<void> saveEvent(EventModel event) async {
    _webCache[event.id] = event;
    final db = await _db.database;
    if (db == null) return;

    await db.insert(
      LocalTables.cachedEvents,
      {
        LocalTables.colId: event.id,
        LocalTables.colJson: jsonEncode(event.toJson()),
        LocalTables.colUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieve all cached events from local storage.
  Future<List<EventModel>> getCachedEvents() async {
    final db = await _db.database;
    if (db == null) {
      return _webCache.values.toList();
    }

    final rows = await db.query(
      LocalTables.cachedEvents,
      orderBy: '${LocalTables.colUpdatedAt} DESC',
    );
    if (rows.isEmpty) {
      return _webCache.values.toList();
    }

    final events = <EventModel>[];
    for (final row in rows) {
      final jsonStr = row[LocalTables.colJson] as String?;
      if (jsonStr == null) continue;
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        events.add(EventModel.fromJson(map));
      } catch (_) {
        // Skip corrupt cache row gracefully
      }
    }
    return events.isNotEmpty ? events : _webCache.values.toList();
  }

  /// Retrieve a cached event by ID.
  Future<EventModel?> getCachedEvent(String eventId) async {
    final db = await _db.database;
    if (db == null) {
      return _webCache[eventId];
    }

    final rows = await db.query(
      LocalTables.cachedEvents,
      where: '${LocalTables.colId} = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return _webCache[eventId];
    }
    final jsonStr = rows.first[LocalTables.colJson] as String?;
    if (jsonStr == null) return _webCache[eventId];
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return EventModel.fromJson(map);
    } catch (_) {
      return _webCache[eventId];
    }
  }

  /// Delete a cached event by ID.
  Future<void> deleteCachedEvent(String eventId) async {
    _webCache.remove(eventId);
    final db = await _db.database;
    if (db == null) return;

    await db.delete(
      LocalTables.cachedEvents,
      where: '${LocalTables.colId} = ?',
      whereArgs: [eventId],
    );
  }

  /// Clear all cached events.
  Future<void> clearAll() async {
    _webCache.clear();
    final db = await _db.database;
    if (db == null) return;

    await db.delete(LocalTables.cachedEvents);
  }
}

final eventCacheDaoProvider = Provider<EventCacheDao>(
  (_) => EventCacheDao(),
);

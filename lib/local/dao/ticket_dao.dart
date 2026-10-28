import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/registration/data/models/registration_model.dart';
import '../../shared/enums/registration_status.dart';
import '../app_database.dart';
import '../local_tables.dart';

class OfflineTicketRecord {
  const OfflineTicketRecord({
    required this.registrationId,
    required this.userId,
    required this.eventId,
    required this.qrToken,
    required this.eventTitle,
    required this.startAt,
    required this.updatedAt,
    this.status = RegistrationStatus.registered,
    this.registeredAt,
    this.checkedInAt,
    this.cancelledAt,
  });

  final String registrationId;
  final String userId;
  final String eventId;
  final String qrToken;
  final String eventTitle;
  final DateTime startAt;
  final DateTime updatedAt;
  final RegistrationStatus status;
  final DateTime? registeredAt, checkedInAt, cancelledAt;

  static DateTime? _date(dynamic value) => value is int
      ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
      : null;

  Map<String, dynamic> toMap() => {
    LocalTables.colRegistrationId: registrationId,
    LocalTables.colUserId: userId,
    LocalTables.colEventId: eventId,
    LocalTables.colQrToken: qrToken,
    LocalTables.colEventTitle: eventTitle,
    LocalTables.colStartAt: startAt.millisecondsSinceEpoch,
    LocalTables.colUpdatedAt: updatedAt.millisecondsSinceEpoch,
    'status': status.name,
    'registered_at': registeredAt?.millisecondsSinceEpoch,
    'checked_in_at': checkedInAt?.millisecondsSinceEpoch,
    'cancelled_at': cancelledAt?.millisecondsSinceEpoch,
  };

  factory OfflineTicketRecord.fromMap(Map<String, dynamic> map) =>
      OfflineTicketRecord(
        status: RegistrationStatus.fromString(map['status'] as String?),
        registeredAt: _date(map['registered_at']),
        checkedInAt: _date(map['checked_in_at']),
        cancelledAt: _date(map['cancelled_at']),
        registrationId: map[LocalTables.colRegistrationId] as String,
        userId: map[LocalTables.colUserId] as String,
        eventId: map[LocalTables.colEventId] as String,
        qrToken: map[LocalTables.colQrToken] as String,
        eventTitle: map[LocalTables.colEventTitle] as String,
        startAt: DateTime.fromMillisecondsSinceEpoch(
          map[LocalTables.colStartAt] as int,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          map[LocalTables.colUpdatedAt] as int,
        ),
      );

  RegistrationModel toRegistrationModel() => RegistrationModel(
    id: registrationId,
    eventId: eventId,
    userId: userId,
    status: status,
    qrToken: qrToken,
    registeredAt: registeredAt ?? updatedAt,
    checkedInAt: checkedInAt,
    cancelledAt: cancelledAt,
    isFromCache: true,
  );
}

class TicketDao {
  TicketDao([AppDatabase? database]) : _db = database ?? AppDatabase.instance;

  final AppDatabase _db;
  // In-memory cache fallback for web environment where SQLite binary is unavailable
  static final Map<String, OfflineTicketRecord> _webCache = {};

  Future<void> saveTicket({
    required RegistrationModel registration,
    required String eventTitle,
    required DateTime startAt,
  }) async {
    final record = OfflineTicketRecord(
      registrationId: registration.id,
      userId: registration.userId,
      eventId: registration.eventId,
      qrToken: registration.qrToken,
      eventTitle: eventTitle,
      startAt: startAt,
      updatedAt: DateTime.now(),
      status: registration.status,
      registeredAt: registration.registeredAt,
      checkedInAt: registration.checkedInAt,
      cancelledAt: registration.cancelledAt,
    );

    _webCache[registration.id] = record;

    final db = await _db.database;
    if (db == null) return;

    await db.insert(
      LocalTables.offlineTickets,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<OfflineTicketRecord?> getTicket(String registrationId) async {
    final db = await _db.database;
    if (db == null) {
      return _webCache[registrationId];
    }

    final rows = await db.query(
      LocalTables.offlineTickets,
      where: '${LocalTables.colRegistrationId} = ?',
      whereArgs: [registrationId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return OfflineTicketRecord.fromMap(rows.first);
  }

  Future<List<OfflineTicketRecord>> getMyTickets(String userId) async {
    final db = await _db.database;
    if (db == null) {
      final list = _webCache.values.where((t) => t.userId == userId).toList();
      list.sort((a, b) => a.startAt.compareTo(b.startAt));
      return list;
    }

    final rows = await db.query(
      LocalTables.offlineTickets,
      where: '${LocalTables.colUserId} = ?',
      whereArgs: [userId],
      orderBy: '${LocalTables.colStartAt} ASC',
    );

    return rows.map(OfflineTicketRecord.fromMap).toList();
  }

  Future<void> deleteTicket(String registrationId) async {
    _webCache.remove(registrationId);
    final db = await _db.database;
    if (db == null) return;

    await db.delete(
      LocalTables.offlineTickets,
      where: '${LocalTables.colRegistrationId} = ?',
      whereArgs: [registrationId],
    );
  }
}

final ticketDaoProvider = Provider<TicketDao>((ref) => TicketDao());

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/enums/event_status.dart';

/// Shared event schema from the master blueprint. Dates are stored as UTC.
class EventModel {
  const EventModel({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.description,
    required this.category,
    required this.locationName,
    required this.startAt,
    required this.endAt,
    required this.capacity,
    required this.registeredCount,
    required this.checkedInCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.clubId,
    this.posterUrl,
    this.latitude,
    this.longitude,
  });

  final String id, organizerId, title, description, category, locationName;
  final String? clubId, posterUrl;
  final double? latitude, longitude;
  final DateTime startAt, endAt, createdAt, updatedAt;
  final int capacity, registeredCount, checkedInCount;
  final EventStatus status;

  String get titleLower => title.toLowerCase();
  int get availablePlaces => (capacity - registeredCount).clamp(0, capacity);
  bool get isFull => registeredCount >= capacity;

  // ── UC-016: Derived read helpers shared by Discovery screens ─────────────
  bool get isPublished => status == EventStatus.published;
  bool get isCancelled => status == EventStatus.cancelled;

  /// True while the event can still be discovered/joined by students.
  bool isUpcomingAt(DateTime now) =>
      isPublished && !startAt.isBefore(now.toUtc());

  bool hasStartedAt(DateTime now) => !startAt.isAfter(now.toUtc());

  /// Registration ratio in the range 0..1, used to rank popular events.
  double get fillRate =>
      capacity == 0 ? 0 : (registeredCount / capacity).clamp(0, 1).toDouble();

  /// Case-insensitive keyword match on title, location and category.
  bool matchesKeyword(String keyword) {
    final query = keyword.trim().toLowerCase();
    if (query.isEmpty) return true;
    return titleLower.contains(query) ||
        locationName.toLowerCase().contains(query) ||
        category.toLowerCase().contains(query);
  }

  EventModel copyWith({
    String? title,
    String? description,
    String? category,
    String? locationName,
    DateTime? startAt,
    DateTime? endAt,
    int? capacity,
    int? registeredCount,
    int? checkedInCount,
    EventStatus? status,
    DateTime? updatedAt,
    String? posterUrl,
  }) => EventModel(
    id: id,
    organizerId: organizerId,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    locationName: locationName ?? this.locationName,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    capacity: capacity ?? this.capacity,
    registeredCount: registeredCount ?? this.registeredCount,
    checkedInCount: checkedInCount ?? this.checkedInCount,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    clubId: clubId,
    posterUrl: posterUrl ?? this.posterUrl,
    latitude: latitude,
    longitude: longitude,
  );

  /// Firestore-independent JSON (dates as epoch milliseconds, UTC) used by
  /// the SQLite `cached_events` table and offline fallbacks.
  Map<String, dynamic> toJson() => {
    'id': id,
    'organizerId': organizerId,
    'clubId': clubId,
    'title': title,
    'description': description,
    'category': category,
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'startAt': startAt.toUtc().millisecondsSinceEpoch,
    'endAt': endAt.toUtc().millisecondsSinceEpoch,
    'capacity': capacity,
    'registeredCount': registeredCount,
    'checkedInCount': checkedInCount,
    'posterUrl': posterUrl,
    'status': status.name,
    'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
  };

  /// Reverses [toJson]. Reuses [EventModel.fromMap] validation so a corrupt
  /// cache row is rejected with a [FormatException] instead of crashing UI.
  factory EventModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('Invalid cached event id.');
    }
    Timestamp time(String key) {
      final value = json[key];
      if (value is! int) throw FormatException('Invalid cached date: $key');
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }

    return EventModel.fromMap(id, {
      ...json,
      'startAt': time('startAt'),
      'endAt': time('endAt'),
      'createdAt': time('createdAt'),
      'updatedAt': time('updatedAt'),
    });
  }

  factory EventModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw const FormatException('Event does not exist.');
    return EventModel.fromMap(doc.id, data);
  }

  factory EventModel.fromMap(String id, Map<String, dynamic> data) {
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid event field: $key');
      }
      return value;
    }

    DateTime date(String key) {
      final value = data[key];
      if (value is! Timestamp) {
        throw FormatException('Invalid event date: $key');
      }
      return value.toDate().toUtc();
    }

    int count(String key) {
      final value = data[key];
      if (value is! int || value < 0) {
        throw FormatException('Invalid event count: $key');
      }
      return value;
    }

    final start = date('startAt');
    final end = date('endAt');
    final capacity = count('capacity');
    if (capacity == 0 || !end.isAfter(start)) {
      throw const FormatException('Invalid event capacity or dates.');
    }
    final statusName = text('status');
    final status = EventStatus.values
        .where((s) => s.name == statusName)
        .firstOrNull;
    if (status == null) throw const FormatException('Invalid event status.');
    return EventModel(
      id: id,
      organizerId: text('organizerId'),
      clubId: data['clubId'] as String?,
      title: text('title'),
      description: text('description'),
      category: text('category'),
      locationName: text('locationName'),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      startAt: start,
      endAt: end,
      capacity: capacity,
      registeredCount: count('registeredCount'),
      checkedInCount: count('checkedInCount'),
      posterUrl: data['posterUrl'] as String?,
      status: status,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }

  Map<String, dynamic> toMap() => {
    'organizerId': organizerId,
    'clubId': clubId,
    'title': title,
    'titleLower': titleLower,
    'description': description,
    'category': category,
    'locationName': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'startAt': Timestamp.fromDate(startAt.toUtc()),
    'endAt': Timestamp.fromDate(endAt.toUtc()),
    'capacity': capacity,
    'registeredCount': registeredCount,
    'checkedInCount': checkedInCount,
    'posterUrl': posterUrl,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
  };
}

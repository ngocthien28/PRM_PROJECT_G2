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

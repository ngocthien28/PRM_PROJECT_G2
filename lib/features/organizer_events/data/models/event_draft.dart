import 'dart:convert';

/// Raw form values intentionally accept incomplete or invalid published input.
/// Poster bytes and temporary picker paths never enter SQLite.
class EventDraft {
  EventDraft({
    required this.id,
    required this.organizerId,
    required Map<String, dynamic> fields,
    required this.createdAt,
    required this.updatedAt,
  }) : fields = Map.unmodifiable(fields);

  final String id;
  final String organizerId;
  final Map<String, dynamic> fields;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => {
    'id': id,
    'organizer_id': organizerId,
    'payload': jsonEncode(fields),
    'created_at': createdAt.toUtc().millisecondsSinceEpoch,
    'updated_at': updatedAt.toUtc().millisecondsSinceEpoch,
  };

  factory EventDraft.fromMap(Map<String, Object?> row) {
    final fields = Map<String, dynamic>.from(
      jsonDecode(row['payload'] as String) as Map,
    );
    for (final key in [
      'title',
      'description',
      'category',
      'locationName',
      'capacity',
    ]) {
      if (fields[key] is! String) {
        throw FormatException('Invalid draft field: $key');
      }
    }
    for (final key in ['startAt', 'endAt']) {
      DateTime.parse(fields[key] as String);
    }
    return EventDraft(
      id: row['id'] as String,
      organizerId: row['organizer_id'] as String,
      fields: fields,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
        isUtc: true,
      ),
    );
  }
}

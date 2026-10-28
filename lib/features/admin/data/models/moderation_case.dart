import 'package:cloud_firestore/cloud_firestore.dart';

enum ModerationStatus {
  pending,
  resolved,
  dismissed;

  static ModerationStatus parse(String value) => values.firstWhere(
    (status) => status.name == value,
    orElse: () => pending,
  );
}

enum ModerationAction {
  resolve('Resolve issue', 'The reported issue was handled.'),
  dismiss('Dismiss report', 'No policy violation was found.');

  const ModerationAction(this.label, this.description);
  final String label;
  final String description;
}

class ModerationCase {
  const ModerationCase({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.description,
    required this.reporterName,
    required this.status,
    required this.createdAt,
    this.resolution,
    this.resolutionAction,
    this.resolvedBy,
    this.resolvedAt,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String title;
  final String description;
  final String reporterName;
  final ModerationStatus status;
  final DateTime createdAt;
  final String? resolution;
  final String? resolutionAction;
  final String? resolvedBy;
  final DateTime? resolvedAt;

  factory ModerationCase.fromMap(String id, Map<String, dynamic> data) {
    DateTime? timestamp(Object? value) => switch (value) {
      Timestamp() => value.toDate().toUtc(),
      DateTime() => value.toUtc(),
      _ => null,
    };

    return ModerationCase(
      id: id,
      targetType: data['targetType'] as String? ?? 'other',
      targetId: data['targetId'] as String? ?? '',
      title: data['title'] as String? ?? 'Moderation report',
      description: data['description'] as String? ?? '',
      reporterName: data['reporterName'] as String? ?? 'Campus member',
      status: ModerationStatus.parse(data['status'] as String? ?? 'pending'),
      createdAt: timestamp(data['createdAt']) ?? DateTime.now().toUtc(),
      resolution: data['resolution'] as String?,
      resolutionAction: data['resolutionAction'] as String?,
      resolvedBy: data['resolvedBy'] as String?,
      resolvedAt: timestamp(data['resolvedAt']),
    );
  }
}

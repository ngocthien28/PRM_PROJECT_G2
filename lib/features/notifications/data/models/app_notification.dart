import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.referenceId,
  });
  final String id, userId, title, body, type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    userId: userId,
    title: title,
    body: body,
    type: type,
    referenceId: referenceId,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    final date = data['createdAt'];
    if (date != null && date is! Timestamp) {
      throw const FormatException('Invalid notification timestamp.');
    }
    return AppNotification(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? '',
      referenceId: data['referenceId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: date is Timestamp
          ? date.toDate().toUtc()
          : DateTime.now().toUtc(),
    );
  }
  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'referenceId': referenceId,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
  };

  factory AppNotification.fromCacheMap(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    if (createdAt is! int) {
      throw const FormatException('Invalid cached notification timestamp.');
    }
    return AppNotification(
      id: data['id'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? '',
      referenceId: data['referenceId'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
    );
  }

  Map<String, dynamic> toCacheMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'referenceId': referenceId,
    'isRead': isRead,
    'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
  };
}

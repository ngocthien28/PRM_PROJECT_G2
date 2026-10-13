import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/enums/club_status.dart';

class ClubModel {
  const ClubModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.logoUrl,
    this.logoPublicId,
  });
  final String id, ownerId, name, description;
  final String? logoUrl, logoPublicId;
  final int memberCount;
  final ClubStatus status;
  final DateTime createdAt, updatedAt;
  String get nameLower => name.trim().toLowerCase();
  bool get isActive => status == ClubStatus.active;

  factory ClubModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw const FormatException('Club does not exist.');
    return ClubModel.fromMap(doc.id, data);
  }
  factory ClubModel.fromMap(String id, Map<String, dynamic> data) {
    String text(String key) {
      final value = data[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid club field: $key');
      }
      return value.trim();
    }

    DateTime date(String key) {
      final value = data[key];
      if (value == null) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      if (value is Timestamp) {
        return value.toDate().toUtc();
      }
      throw FormatException('Invalid club timestamp: $key');
    }

    final count = data['memberCount'];
    if (count is! int || count < 0) {
      throw const FormatException('Invalid club memberCount.');
    }
    return ClubModel(
      id: id,
      ownerId: text('ownerId'),
      name: text('name'),
      description: text('description'),
      logoUrl: data['logoUrl'] as String?,
      logoPublicId: data['logoPublicId'] as String?,
      memberCount: count,
      status: ClubStatus.parse(text('status')),
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
    );
  }
  Map<String, dynamic> toMap() => {
    'ownerId': ownerId,
    'name': name.trim(),
    'nameLower': nameLower,
    'description': description.trim(),
    'logoUrl': logoUrl,
    'logoPublicId': logoPublicId,
    'memberCount': memberCount,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
  };
  ClubModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? description,
    String? logoUrl,
    String? logoPublicId,
    int? memberCount,
    ClubStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ClubModel(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    description: description ?? this.description,
    logoUrl: logoUrl ?? this.logoUrl,
    logoPublicId: logoPublicId ?? this.logoPublicId,
    memberCount: memberCount ?? this.memberCount,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

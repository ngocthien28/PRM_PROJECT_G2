import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/enums/membership_status.dart';

class ClubMembership {
  const ClubMembership({
    required this.id,
    required this.clubId,
    required this.userId,
    required this.role,
    required this.status,
    required this.joinedAt,
    required this.updatedAt,
  });
  final String id, clubId, userId;
  final MembershipRole role;
  final MembershipStatus status;
  final DateTime joinedAt, updatedAt;
  static String documentId(String clubId, String userId) => '${clubId}_$userId';
  bool get isActive => status == MembershipStatus.active;
  factory ClubMembership.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) throw const FormatException('Membership does not exist.');
    return ClubMembership.fromMap(doc.id, data);
  }
  factory ClubMembership.fromMap(String id, Map<String, dynamic> data) {
    DateTime date(String key) {
      final value = data[key];
      if (value == null) {
        return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
      if (value is Timestamp) {
        return value.toDate().toUtc();
      }
      throw FormatException('Invalid membership timestamp: $key');
    }

    final clubId = data['clubId'], userId = data['userId'];
    if (clubId is! String ||
        clubId.isEmpty ||
        userId is! String ||
        userId.isEmpty) {
      throw const FormatException('Invalid membership identity.');
    }
    return ClubMembership(
      id: id,
      clubId: clubId,
      userId: userId,
      role: MembershipRole.parse(data['role'] as String? ?? ''),
      status: MembershipStatus.parse(data['status'] as String? ?? ''),
      joinedAt: date('joinedAt'),
      updatedAt: date('updatedAt'),
    );
  }
  Map<String, dynamic> toMap() => {
    'clubId': clubId,
    'userId': userId,
    'role': role.name,
    'status': status.name,
    'joinedAt': Timestamp.fromDate(joinedAt.toUtc()),
    'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
  };
}

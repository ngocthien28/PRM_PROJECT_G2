import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/enums/user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? phone;
  final UserRole role;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.phone,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  bool get isActive => status == 'active';
  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: map['uid'] as String,
    email: map['email'] as String,
    displayName: map['displayName'] as String,
    avatarUrl: map['avatarUrl'] as String?,
    phone: map['phone'] as String?,
    role: UserRole.parse(map['role'] as String),
    status: map['status'] as String,
    createdAt: (map['createdAt'] as Timestamp).toDate().toUtc(),
    updatedAt: (map['updatedAt'] as Timestamp).toDate().toUtc(),
  );
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    if (phone != null) 'phone': phone,
    'role': role.name,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt.toUtc()),
    'updatedAt': Timestamp.fromDate(updatedAt.toUtc()),
  };
}

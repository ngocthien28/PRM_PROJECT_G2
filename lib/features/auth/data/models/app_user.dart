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
  /// FEATURE: UC-002, UC-003, UC-015
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Chuyển status active thành điều kiện route và kiểm tra actor.
  /// ROLE: Account status model
  /// CALLED FROM: sessionRedirect và module authorization.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK.
  bool get isActive => status == 'active';
  /// FEATURE: UC-002, UC-003, UC-008, UC-011
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Giải mã profile Firestore/cache; parse role nghiêm ngặt và chuyển timestamp về UTC.
  /// ROLE: Profile serialization
  /// CALLED FROM: ProfileRepositoryImpl.watchUser và LocalProfileCache.readProfile.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK.
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
  /// FEATURE: UC-008, UC-011
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Mã hóa profile cùng role/status và Timestamp để cache lưu bản sao theo UID.
  /// ROLE: Profile serialization
  /// CALLED FROM: LocalProfileCache.saveProfile và tests.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Cloud Firestore SDK.
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

enum UserRole {
  student,
  organizer,
  admin;

  /// FEATURE: UC-003, UC-015
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Cho organizer/admin dùng khả năng quản lý chung.
  /// ROLE: Role capability
  /// CALLED FROM: Route guards và Event/Club/Registration.
  /// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  bool get canOrganize => this == organizer || this == admin;
  /// FEATURE: UC-002, UC-003
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Đọc role đã biết và ném FormatException khi role không hợp lệ.
  /// ROLE: Fail-closed role parsing
  /// CALLED FROM: AppUser.fromMap.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static UserRole parse(String value) => values.firstWhere(
    (role) => role.name == value,
    orElse: () => throw const FormatException('Unknown user role'),
  );
}

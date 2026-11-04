class AppException implements Exception {
  final String message;
  final String code;
  final Object? cause;
  const AppException(this.message, {this.code = 'unknown', this.cause});
  /// FEATURE: UC-013 - Implement Shared Loading and Error Handling
  /// MODULE: App Shell
  /// DESCRIPTION: Trả message để UI hiển thị thông báo lỗi miền đã ánh xạ.
  /// ROLE: Domain error presentation
  /// CALLED FROM: Các widget dùng error.toString.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  @override
  String toString() => message;
}

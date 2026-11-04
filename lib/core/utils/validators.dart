class Validators {
  /// FEATURE: UC-004, UC-005, UC-006, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Bắt buộc email và kiểm tra định dạng sau trim.
  /// ROLE: Client form validation
  /// CALLED FROM: AuthForm hoặc EditProfileScreen/ProfileViewModel.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// FEATURE: UC-004, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Bắt buộc password đăng ký ít nhất 8 ký tự, giữ nguyên whitespace.
  /// ROLE: Client form validation
  /// CALLED FROM: AuthForm hoặc EditProfileScreen/ProfileViewModel.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 8) return 'Password must have at least 8 characters.';
    return null;
  }

  // Existing Firebase accounts may have passwords shorter than the new policy.
  /// FEATURE: UC-005, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Bắt buộc password đăng nhập; cho phép account cũ ngắn hơn chính sách mới.
  /// ROLE: Client form validation
  /// CALLED FROM: AuthForm hoặc EditProfileScreen/ProfileViewModel.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String? loginPassword(String? value) =>
      value == null || value.isEmpty ? 'Password is required.' : null;
  /// FEATURE: UC-004, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Bắt buộc confirm khớp chính xác password.
  /// ROLE: Client form validation
  /// CALLED FROM: AuthForm hoặc EditProfileScreen/ProfileViewModel.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String? confirmPassword(String? value, String password) =>
      value == null || value.isEmpty
      ? 'Please confirm your password.'
      : value != password
      ? 'Passwords do not match.'
      : null;
  /// FEATURE: UC-004, UC-009, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Giới hạn tên sau trim từ 2 đến 50 ký tự.
  /// ROLE: Client form validation
  /// CALLED FROM: AuthForm hoặc EditProfileScreen/ProfileViewModel.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String? displayName(String? value) {
    final length = value?.trim().length ?? 0;
    return length < 2 || length > 50 ? 'Name must have 2–50 characters.' : null;
  }

  /// FEATURE: UC-009, UC-012
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Cho phone trống; kiểm tra tập ký tự, độ dài và ít nhất 7 chữ số.
  /// ROLE: Client form validation
  /// CALLED FROM: AuthForm hoặc EditProfileScreen/ProfileViewModel.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  static String? phone(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return null;
    if (!RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(phone) ||
        phone.replaceAll(RegExp(r'\D'), '').length < 7) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }
}

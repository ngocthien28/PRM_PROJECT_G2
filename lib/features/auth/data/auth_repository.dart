class AuthIdentity {
  final String uid;
  final String email;
  final String? displayName;
  const AuthIdentity({
    required this.uid,
    required this.email,
    this.displayName,
  });
}

abstract class AuthRepository {
  /// FEATURE: UC-002 - Configure Firebase Authentication and Auth State
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khai báo hợp đồng watchUser được AuthRepositoryImpl thực thi bằng Firebase Auth.
  /// ROLE: Authentication repository contract
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  Stream<AuthIdentity?> watchUser();
  /// FEATURE: UC-005 - Log In
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khai báo hợp đồng signIn được AuthRepositoryImpl thực thi bằng Firebase Auth.
  /// ROLE: Authentication repository contract
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  Future<void> signIn(String email, String password);
  /// FEATURE: UC-004 - Register Account
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khai báo hợp đồng register được AuthRepositoryImpl thực thi bằng Firebase Auth.
  /// ROLE: Authentication repository contract
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  Future<void> register(String email, String password, String displayName);
  /// FEATURE: UC-006 - Reset Password
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khai báo hợp đồng resetPassword được AuthRepositoryImpl thực thi bằng Firebase Auth.
  /// ROLE: Authentication repository contract
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  Future<void> resetPassword(String email);
  /// FEATURE: UC-007 - Log Out
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khai báo hợp đồng signOut được AuthRepositoryImpl thực thi bằng Firebase Auth.
  /// ROLE: Authentication repository contract
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart.
  Future<void> signOut();
}

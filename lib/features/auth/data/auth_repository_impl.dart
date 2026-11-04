import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_mapper.dart';
import '../../profile/data/profile_repository.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth auth;
  final ProfileRepository profiles;
  AuthRepositoryImpl(this.auth, this.profiles);
  /// FEATURE: UC-002 - Configure Firebase Authentication and Auth State
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Reload phiên khôi phục; signOut token không hợp lệ rồi phát AuthIdentity từ userChanges và ánh xạ lỗi.
  /// ROLE: Firebase Auth SDK integration
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK.
  @override
  Stream<AuthIdentity?> watchUser() async* {
    try {
      // Validate restored sessions, including accounts disabled on the server.
      // Reload once before listening, avoiding a userChanges/reload loop.
      final restoredUser = auth.currentUser;
      if (restoredUser != null) {
        try {
          await restoredUser.reload();
        } on FirebaseAuthException catch (error) {
          // A cached session may belong to a different backend (for example,
          // after switching between the emulator and Firebase).
          if (!{
            'invalid-user-token',
            'user-token-expired',
            'user-not-found',
          }.contains(error.code)) {
            if ({
              'unknown',
              'unknown-error',
              'internal-error',
            }.contains(error.code)) {
              throw AppException(
                'Your saved session could not be restored. Retry, or sign out '
                'and sign in again.',
                code: error.code,
                cause: error,
              );
            }
            rethrow;
          }
          await auth.signOut();
        }
      }
      await for (final user in auth.userChanges()) {
        yield user == null
            ? null
            : AuthIdentity(
                uid: user.uid,
                email: user.email ?? '',
                displayName: user.displayName,
              );
      }
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  /// FEATURE: UC-004, UC-005, UC-006, UC-007, UC-013
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Bao thao tác Auth SDK để mọi lỗi đi qua mapError trước khi trả về view model.
  /// ROLE: Repository error boundary
  /// CALLED FROM: signIn, register, resetPassword, signOut.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK.
  Future<void> _request(Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      throw mapError(error, stack);
    }
  }

  /// FEATURE: UC-005 - Log In
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Chuẩn hóa email, giữ nguyên password và gọi signInWithEmailAndPassword.
  /// ROLE: Firebase Auth SDK integration
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK.
  @override
  Future<void> signIn(String email, String password) => _request(() async {
    await auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  });
  /// FEATURE: UC-004 - Register Account
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Tạo Firebase account, cập nhật displayName và ensureInitialProfile; giữ account khi profile lỗi để phục hồi.
  /// ROLE: Firebase Auth SDK integration
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK.
  @override
  Future<void> register(
    String email,
    String password,
    String displayName,
  ) => _request(() async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = credential.user!;
    try {
      await user.updateDisplayName(displayName.trim());
      await profiles.ensureInitialProfile(
        uid: user.uid,
        email: user.email!,
        displayName: displayName,
      );
    } catch (error, stack) {
      final failure = mapError(error, stack);
      // Auth + Firestore are not atomic. Retain the account for idempotent retry.
      throw AppException(
        'Your account was created, but profile setup failed. '
        'Retry profile setup or sign in again later. ${failure.message}',
        code: 'profile-create-failed',
        cause: failure,
      );
    }
  });
  /// FEATURE: UC-006 - Reset Password
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Chuẩn hóa email và gọi sendPasswordResetEmail qua wrapper ánh xạ lỗi.
  /// ROLE: Firebase Auth SDK integration
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK.
  @override
  Future<void> resetPassword(String email) => _request(
    () => auth.sendPasswordResetEmail(email: email.trim().toLowerCase()),
  );
  /// FEATURE: UC-007 - Log Out
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Gọi FirebaseAuth.signOut qua wrapper ánh xạ lỗi.
  /// ROLE: Firebase Auth SDK integration
  /// CALLED FROM: AuthViewModel hoặc authStateProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK.
  @override
  Future<void> signOut() => _request(auth.signOut);
}

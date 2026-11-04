import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/auth_repository.dart';
import '../../data/models/app_user.dart';
import '../../../profile/data/local_profile_cache.dart';

/// FEATURE: UC-002 - Configure Firebase Authentication and Auth State
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Chuyển stream AuthRepository.watchUser thành AsyncValue; tắt tự retry để UI điều khiển recovery.
/// ROLE: Authentication state
/// CALLED FROM: currentUserProvider, router và auth UI.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
final authStateProvider = StreamProvider<AuthIdentity?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
  retry: (_, _) => null,
);
/// FEATURE: UC-002, UC-008, UC-011, UC-015
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Nối identity với stream profile; lưu cache nhưng không dùng profile cache để cấp quyền.
/// ROLE: Session profile state
/// CALLED FROM: Router, profile UI và module đọc currentUserProvider.
/// RELATED FILES: lib/core/routing/route_guards.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream.empty();
  if (auth.hasError) return Stream.error(auth.error!, auth.stackTrace);
  final identity = auth.asData?.value;
  if (identity == null) return Stream.value(null);
  final profiles = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(localProfileCacheProvider);

  /// FEATURE: UC-002, UC-008, UC-011
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Theo dõi profile đúng UID, lưu cache nếu có user và kiểm tra mounted trước khi phát dữ liệu.
  /// ROLE: Profile stream / local persistence
  /// CALLED FROM: currentUserProvider.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Stream<AppUser?> watchProfile() async* {
    // Persist profiles for local features, but obtain session roles/status from
    // the repository stream. A stale local role must not unlock a module.
    if (!ref.mounted) return;
    await for (final user in profiles.watchUser(identity.uid)) {
      if (!ref.mounted) return;
      if (user != null) {
        try {
          await cache.saveProfile(user);
        } catch (_) {}
      }
      if (!ref.mounted) return;
      yield user;
    }
  }

  return watchProfile();
}, retry: (_, _) => null);
/// FEATURE: UC-004, UC-005, UC-006, UC-007, UC-013
/// MODULE: Authentication & Authorization
/// DESCRIPTION: Cung cấp AuthViewModel và AsyncValue phản hồi chung cho form, splash và logout.
/// ROLE: Action state provider
/// CALLED FROM: AuthForm, SplashScreen và CampusScaffold.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Riverpod.
final authViewModelProvider =
    NotifierProvider<AuthViewModel, AsyncValue<String?>>(AuthViewModel.new);

class AuthViewModel extends Notifier<AsyncValue<String?>> {
  /// FEATURE: UC-004, UC-005, UC-006, UC-007, UC-013
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khởi tạo action feedback rỗng khi tạo AuthViewModel.
  /// ROLE: Action state initialization
  /// CALLED FROM: Riverpod Notifier lifecycle.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  @override
  AsyncValue<String?> build() => const AsyncData(null);
  /// FEATURE: UC-004, UC-005, UC-006, UC-007, UC-013
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Chặn gửi trùng; chuyển loading sang success hoặc mapped error khi notifier còn mounted.
  /// ROLE: Async action state
  /// CALLED FROM: signIn, register, resetPassword, signOut và recoverProfile.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Future<void> _submit(Future<void> Function() action, String? message) async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    try {
      await action();
      if (ref.mounted) state = AsyncData(message);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(mapError(error, stack), stack);
    }
  }

  /// FEATURE: UC-005 - Log In
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Gọi authRepository.signIn và công bố thông báo đăng nhập thành công.
  /// ROLE: Authentication action
  /// CALLED FROM: AuthForm, SplashScreen hoặc nút logout.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Future<void> signIn(String email, String password) => _submit(
    () => ref.read(authRepositoryProvider).signIn(email, password),
    'Signed in successfully.',
  );
  /// FEATURE: UC-004 - Register Account
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Gọi authRepository.register và công bố phản hồi tạo tài khoản.
  /// ROLE: Authentication action
  /// CALLED FROM: AuthForm, SplashScreen hoặc nút logout.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Future<void> register(String email, String password, String displayName) =>
      _submit(
        () => ref
            .read(authRepositoryProvider)
            .register(email, password, displayName),
        'Account created successfully.',
      );
  /// FEATURE: UC-006 - Reset Password
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Gửi yêu cầu reset và phản hồi trung tính không tiết lộ email có tài khoản hay không.
  /// ROLE: Authentication action
  /// CALLED FROM: AuthForm, SplashScreen hoặc nút logout.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Future<void> resetPassword(String email) => _submit(
    () => ref.read(authRepositoryProvider).resetPassword(email),
    'If an account exists for this email, a password reset email has been sent.',
  );
  /// FEATURE: UC-007 - Log Out
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Unregister thông báo, signOut Auth rồi invalidate identity và profile providers.
  /// ROLE: Authentication action
  /// CALLED FROM: AuthForm, SplashScreen hoặc nút logout.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Future<void> signOut() => _submit(() async {
    await NotificationService.instance.unregister();
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(authStateProvider);
    ref.invalidate(currentUserProvider);
  }, null);
  /// FEATURE: UC-002, UC-004
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Khôi phục profile thiếu bằng identity hiện tại; không nâng quyền hoặc ghi đè profile đã có.
  /// ROLE: Authentication action
  /// CALLED FROM: AuthForm, SplashScreen hoặc nút logout.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  Future<void> recoverProfile() => _submit(() async {
    final identity = ref.read(authStateProvider).asData?.value;
    if (identity == null) {
      throw const AppException('Please sign in again.', code: 'session-ended');
    }
    final name = identity.displayName?.trim();
    await ref
        .read(profileRepositoryProvider)
        .ensureInitialProfile(
          uid: identity.uid,
          email: identity.email,
          displayName: name != null && name.length >= 2 ? name : 'Student',
        );
    ref.invalidate(currentUserProvider);
  }, 'Profile setup completed.');
  /// FEATURE: UC-002, UC-013
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Xóa feedback khi không bận và invalidate Auth/profile streams để thử lại phiên.
  /// ROLE: Session recovery
  /// CALLED FROM: SplashScreen Retry.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  void retrySession() {
    if (state.isLoading) return;
    state = const AsyncData(null);
    ref.invalidate(authStateProvider);
    ref.invalidate(currentUserProvider);
  }

  /// FEATURE: UC-004, UC-005, UC-006, UC-013
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Xóa thông báo cũ khi chuyển form nếu không có request đang chạy.
  /// ROLE: Form feedback lifecycle
  /// CALLED FROM: AuthForm._navigate.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Riverpod.
  void clearFeedback() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}

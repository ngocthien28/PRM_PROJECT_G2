import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../core/services/notification_service.dart';
import '../../data/auth_repository.dart';
import '../../data/models/app_user.dart';
import '../../../profile/data/local_profile_cache.dart';

final authStateProvider = StreamProvider<AuthIdentity?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
  retry: (_, _) => null,
);
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return const Stream.empty();
  if (auth.hasError) return Stream.error(auth.error!, auth.stackTrace);
  final identity = auth.asData?.value;
  if (identity == null) return Stream.value(null);
  final profiles = ref.watch(profileRepositoryProvider);
  final cache = ref.watch(localProfileCacheProvider);

  Stream<AppUser?> watchProfile() async* {
    try {
      final cached = await cache.readProfile(identity.uid);
      if (!ref.mounted) return;
      if (cached != null && cached.uid == identity.uid) yield cached;
    } catch (_) {
      // Local cache failures must not prevent loading the remote profile.
    }
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
final authViewModelProvider =
    NotifierProvider<AuthViewModel, AsyncValue<String?>>(AuthViewModel.new);

class AuthViewModel extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData(null);
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

  Future<void> signIn(String email, String password) => _submit(
    () => ref.read(authRepositoryProvider).signIn(email, password),
    'Signed in successfully.',
  );
  Future<void> register(String email, String password, String displayName) =>
      _submit(
        () => ref
            .read(authRepositoryProvider)
            .register(email, password, displayName),
        'Account created successfully.',
      );
  Future<void> resetPassword(String email) => _submit(
    () => ref.read(authRepositoryProvider).resetPassword(email),
    'If an account exists for this email, a password reset email has been sent.',
  );
  Future<void> signOut() => _submit(() async {
    await NotificationService.instance.unregister();
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(authStateProvider);
    ref.invalidate(currentUserProvider);
  }, null);
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
  void retrySession() {
    if (state.isLoading) return;
    state = const AsyncData(null);
    ref.invalidate(authStateProvider);
    ref.invalidate(currentUserProvider);
  }

  void clearFeedback() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}

import 'package:campushub/features/profile/data/local_profile_cache.dart';
import 'dart:async';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_fakes.dart';

/// FEATURE: UC-014 - Test Authentication and Profile
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm void main: Async state, submit trùng, recovery, account switch và logout.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, flutter_test, Riverpod.
void main() {
  late FakeProfiles profiles;
  late FakeAuth auth;
  late ProviderContainer container;
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Thiết lập/thu hồi fixture: Async state, submit trùng, recovery, account switch và logout.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        localProfileCacheProvider.overrideWithValue(FakeLocalProfileCache()),
      ],
    );
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm void observeSession: Async state, submit trùng, recovery, account switch và logout.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  void observeSession() {
    container.listen(currentUserProvider, (_, _) {});
    container.listen(authStateProvider, (_, _) {});
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Thiết lập/thu hồi fixture: Async state, submit trùng, recovery, account switch và logout.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  tearDown(() async {
    container.dispose();
    await auth.dispose();
    await profiles.dispose();
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: sign in moves loading to success and updates current user.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('sign in moves loading to success and updates current user', () async {
    profiles.users['uid'] = testUser();
    observeSession();
    await container.read(currentUserProvider.future);
    final future = container
        .read(authViewModelProvider.notifier)
        .signIn('uid@example.com', 'secret');
    expect(container.read(authViewModelProvider).isLoading, isTrue);
    await future;
    expect(container.read(authViewModelProvider).hasError, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect((await container.read(currentUserProvider.future))?.uid, 'uid');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: startup auth error is exposed as state and a later login recovers.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test(
    'startup auth error is exposed as state and a later login recovers',
    () async {
      final sessions = StreamController<AuthIdentity?>();
      final scoped = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => sessions.stream),
          profileRepositoryProvider.overrideWithValue(profiles),
          localProfileCacheProvider.overrideWithValue(FakeLocalProfileCache()),
        ],
      );
      addTearDown(scoped.dispose);
      addTearDown(sessions.close);
      scoped.listen(currentUserProvider, (_, _) {});
      final failed = expectLater(
        scoped.read(currentUserProvider.future),
        throwsA(isA<AppException>()),
      );
      sessions.addError(
        const AppException('Cannot connect.', code: 'network-request-failed'),
      );
      await failed;
      expect(scoped.read(currentUserProvider).hasError, isTrue);
      profiles.users['uid'] = testUser();
      sessions.add(testIdentity);
      await Future<void>.delayed(Duration.zero);
      expect((await scoped.read(currentUserProvider.future))?.uid, 'uid');
    },
  );
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: request error stops loading with a readable error.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('request error stops loading with a readable error', () async {
    auth.failure = const AppException('Email or password is incorrect.');
    await container
        .read(authViewModelProvider.notifier)
        .signIn('x@y.com', 'wrong');
    expect(container.read(authViewModelProvider).isLoading, isFalse);
    expect(
      container.read(authViewModelProvider).error.toString(),
      'Email or password is incorrect.',
    );
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: double submit makes a single repository request.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('double submit makes a single repository request', () async {
    auth.pending = Completer<void>();
    final vm = container.read(authViewModelProvider.notifier);
    final request = vm.signIn('x@y.com', 'password');
    await vm.signIn('x@y.com', 'password');
    expect(auth.calls, 1);
    auth.pending!.complete();
    await request;
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: registration success creates student profile.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('registration success creates student profile', () async {
    await container
        .read(authViewModelProvider.notifier)
        .register('uid@example.com', 'password', 'Minh');
    expect(profiles.creates, 1);
    expect(profiles.users['uid']?.role.name, 'student');
    expect(
      container.read(authViewModelProvider).asData?.value,
      'Account created successfully.',
    );
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: partial registration retains account and can recover.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('partial registration retains account and can recover', () async {
    observeSession();
    await container.read(authStateProvider.future);
    await Future<void>.delayed(Duration.zero);
    profiles.failure = const AppException('Cannot connect.');
    await container
        .read(authViewModelProvider.notifier)
        .register('uid@example.com', 'password', 'Minh');
    expect(auth.identity?.uid, 'uid');
    expect(
      (container.read(authViewModelProvider).error as AppException).code,
      'profile-create-failed',
    );
    await Future<void>.delayed(Duration.zero);
    profiles.failure = null;
    await container.read(authViewModelProvider.notifier).recoverProfile();
    expect(profiles.users['uid'], isNotNull);
    expect(container.read(authViewModelProvider).hasError, isFalse);
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: reset success and failure are reported.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('reset success and failure are reported', () async {
    final vm = container.read(authViewModelProvider.notifier);
    await vm.resetPassword('uid@example.com');
    expect(
      container.read(authViewModelProvider).asData!.value,
      contains('password reset email'),
    );
    auth.failure = const AppException('Cannot connect.');
    await vm.resetPassword('uid@example.com');
    expect(container.read(authViewModelProvider).hasError, isTrue);
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: logout clears profile without deleting Firestore data.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('logout clears profile without deleting Firestore data', () async {
    auth.identity = testIdentity;
    profiles.users['uid'] = testUser();
    observeSession();
    expect((await container.read(currentUserProvider.future))?.uid, 'uid');
    await container.read(authViewModelProvider.notifier).signOut();
    expect(await container.read(authStateProvider.future), isNull);
    expect(await container.read(currentUserProvider.future), isNull);
    expect(profiles.users['uid'], isNotNull);
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: failed logout keeps the existing session.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('failed logout keeps the existing session', () async {
    auth.identity = testIdentity;
    profiles.users['uid'] = testUser();
    observeSession();
    await container.read(currentUserProvider.future);
    auth.failure = const AppException('Sign out failed.');
    await container.read(authViewModelProvider.notifier).signOut();
    expect(container.read(authViewModelProvider).hasError, isTrue);
    expect(auth.identity?.uid, 'uid');
    expect(container.read(currentUserProvider).asData?.value?.uid, 'uid');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: switching accounts removes the old profile.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('switching accounts removes the old profile', () async {
    auth.identity = testIdentity;
    profiles.users['uid'] = testUser();
    observeSession();
    await container.read(currentUserProvider.future);
    await Future<void>.delayed(Duration.zero);
    auth.emit(const AuthIdentity(uid: 'other', email: 'other@example.com'));
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(currentUserProvider.future), isNull);
    await Future<void>.delayed(Duration.zero);
    profiles.update(testUser(uid: 'other'));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(currentUserProvider).asData?.value?.uid, 'other');
  });
}

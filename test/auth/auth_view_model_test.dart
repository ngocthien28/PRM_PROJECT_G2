import 'dart:async';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_fakes.dart';

void main() {
  late FakeProfiles profiles;
  late FakeAuth auth;
  late ProviderContainer container;
  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
    );
  });
  void observeSession() {
    container.listen(currentUserProvider, (_, _) {});
    container.listen(authStateProvider, (_, _) {});
  }

  tearDown(() async {
    container.dispose();
    await auth.dispose();
    await profiles.dispose();
  });
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
  test('double submit makes a single repository request', () async {
    auth.pending = Completer<void>();
    final vm = container.read(authViewModelProvider.notifier);
    final request = vm.signIn('x@y.com', 'password');
    await vm.signIn('x@y.com', 'password');
    expect(auth.calls, 1);
    auth.pending!.complete();
    await request;
  });
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

// Exercise retained-data states explicitly to verify fail-closed redirects.
// ignore_for_file: invalid_use_of_internal_member

import 'package:campushub/core/routing/route_guards.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// FEATURE: UC-014, UC-015
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm AppUser user: Ma trận direct URL cho guest/disabled/student/organizer/admin.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, flutter_test, Riverpod.
AppUser user(UserRole role, {String uid = 'u1', String status = 'active'}) =>
    AppUser(
      uid: uid,
      email: 'user@example.com',
      displayName: 'Student',
      role: role,
      status: status,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

/// FEATURE: UC-014, UC-015
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm void main: Ma trận direct URL cho guest/disabled/student/organizer/admin.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, flutter_test, Riverpod.
void main() {
  const identity = AsyncData<AuthIdentity?>(
    AuthIdentity(uid: 'u1', email: 'user@example.com'),
  );
  const shared = [
    '/home',
    '/events',
    '/events/e1',
    '/clubs',
    '/clubs/c1',
    '/notifications',
    '/favorites',
    '/my-events',
    '/tickets/t1',
    '/profile',
    '/profile/edit',
  ];
  const organizer = [
    '/organizer',
    '/organizer/events',
    '/organizer/events/create',
    '/organizer/events/e1',
    '/organizer/events/e1/edit',
    '/organizer/events/e1/scan',
    '/organizer/events/e1/participants',
    '/organizer/clubs/new',
    '/organizer/clubs/c1/edit',
  ];
  const admin = ['/admin', '/admin/events', '/admin/moderation'];

  for (final role in UserRole.values) {
    /// FEATURE: UC-014, UC-015
    /// MODULE: Testing & Integration
    /// DESCRIPTION: Kiểm thử: ${role.name}: module access matrix and direct URLs.
    /// ROLE: Existing test callback
    /// CALLED FROM: flutter_test runner / main.
    /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
    /// TECHNOLOGY: Dart, flutter_test, Riverpod.
    test('${role.name}: module access matrix and direct URLs', () {
      for (final path in [...shared, ...organizer, ...admin]) {
        final allowed =
            shared.contains(path) ||
            (organizer.contains(path) && role.canOrganize) ||
            (admin.contains(path) && role == UserRole.admin);
        expect(
          sessionRedirect(
            path: path,
            auth: identity,
            profile: AsyncData(user(role)),
          ),
          allowed ? isNull : roleHome(role),
          reason: path,
        );
        expect(
          sessionRedirect(
            path: path,
            auth: const AsyncData(null),
            profile: AsyncData(user(role)),
          ),
          '/login',
          reason: 'Guest: $path',
        );
        expect(
          sessionRedirect(
            path: path,
            auth: identity,
            profile: AsyncData(user(role, status: 'disabled')),
          ),
          '/splash',
          reason: 'Disabled: $path',
        );
      }
    });
  }

  /// FEATURE: UC-014, UC-015
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: role downgrade and account mismatch revoke module access.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('role downgrade and account mismatch revoke module access', () {
    const path = '/admin/moderation';
    expect(
      sessionRedirect(
        path: path,
        auth: identity,
        profile: AsyncData(user(UserRole.admin)),
      ),
      isNull,
    );
    expect(
      sessionRedirect(
        path: path,
        auth: identity,
        profile: AsyncData(user(UserRole.student)),
      ),
      '/home',
    );
    expect(
      sessionRedirect(
        path: path,
        auth: identity,
        profile: AsyncData(user(UserRole.admin, uid: 'old-user')),
      ),
      '/splash',
    );
  });

  /// FEATURE: UC-014, UC-015
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: retained privileged profile is gated while refreshing or failed.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('retained privileged profile is gated while refreshing or failed', () {
    final previous = AsyncData<AppUser?>(user(UserRole.admin));
    for (final profile in [
      const AsyncLoading<AppUser?>().copyWithPrevious(previous),
      AsyncError<AppUser?>(
        Exception('Denied'),
        StackTrace.empty,
      ).copyWithPrevious(previous),
    ]) {
      expect(
        sessionRedirect(
          path: '/admin/events',
          auth: identity,
          profile: profile,
        ),
        '/splash',
      );
    }
  });

  /// FEATURE: UC-014, UC-015
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: restricted roots match path segments.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('restricted roots match path segments', () {
    expect(isRouteWithin('/admin/moderation', '/admin'), isTrue);
    expect(isRouteWithin('/administrator', '/admin'), isFalse);
    expect(isRouteWithin('/organizer-other', '/organizer'), isFalse);
  });
}

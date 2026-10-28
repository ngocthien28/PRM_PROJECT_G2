// Exercise retained-data states explicitly to verify fail-closed redirects.
// ignore_for_file: invalid_use_of_internal_member

import 'package:campushub/core/routing/route_guards.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('restricted roots match path segments', () {
    expect(isRouteWithin('/admin/moderation', '/admin'), isTrue);
    expect(isRouteWithin('/administrator', '/admin'), isFalse);
    expect(isRouteWithin('/organizer-other', '/organizer'), isFalse);
  });
}

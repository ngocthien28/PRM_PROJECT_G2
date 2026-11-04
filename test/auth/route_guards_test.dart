import 'package:campushub/core/routing/route_guards.dart';
import 'package:campushub/features/auth/data/auth_repository.dart';
import 'package:campushub/features/auth/data/models/app_user.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_fakes.dart';

/// FEATURE: UC-014 - Test Authentication and Profile
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm void main: Role landing, prefix, missing/stale profile và action đang chạy.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, flutter_test, Riverpod.
void main() {
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm String? redirect: Role landing, prefix, missing/stale profile và action đang chạy.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  String? redirect(
    String path, {
    AsyncValue<AuthIdentity?> auth = const AsyncData(testIdentity),
    AsyncValue<AppUser?>? profile,
    bool busy = false,
  }) => sessionRedirect(
    path: path,
    auth: auth,
    profile: profile ?? AsyncData(testUser()),
    actionLoading: busy,
  );
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: loading routes to splash without looping.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('loading routes to splash without looping', () {
    expect(redirect('/home', auth: const AsyncLoading()), '/splash');
    expect(redirect('/splash', auth: const AsyncLoading()), isNull);
    expect(redirect('/home', profile: const AsyncLoading()), '/splash');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: guest can access all auth pages but cannot return to protected pages.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test(
    'guest can access all auth pages but cannot return to protected pages',
    () {
      for (final path in ['/login', '/register', '/forgot-password']) {
        expect(redirect(path, auth: const AsyncData(null)), isNull);
      }
      for (final path in ['/home', '/organizer', '/admin', '/splash']) {
        expect(redirect(path, auth: const AsyncData(null)), '/login');
      }
    },
  );
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: missing, disabled, stale and failed profiles are gated.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('missing, disabled, stale and failed profiles are gated', () {
    expect(redirect('/home', profile: const AsyncData(null)), '/splash');
    expect(
      redirect('/home', profile: AsyncData(testUser(status: 'disabled'))),
      '/splash',
    );
    expect(
      redirect('/home', profile: AsyncData(testUser(uid: 'previous'))),
      '/splash',
    );
    expect(
      redirect('/home', profile: AsyncError(Exception(), StackTrace.empty)),
      '/splash',
    );
    expect(
      redirect('/home', auth: AsyncError(Exception(), StackTrace.empty)),
      '/splash',
    );
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: role landing and restricted prefixes follow agreed contract.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('role landing and restricted prefixes follow agreed contract', () {
    for (final role in UserRole.values) {
      expect(
        redirect('/login', profile: AsyncData(testUser(role: role))),
        roleHome(role),
      );
      expect(
        redirect(roleHome(role), profile: AsyncData(testUser(role: role))),
        isNull,
      );
    }
    expect(redirect('/admin/users'), '/home');
    expect(redirect('/organizer/events'), '/home');
    expect(
      redirect(
        '/admin',
        profile: AsyncData(testUser(role: UserRole.organizer)),
      ),
      '/organizer',
    );
    expect(
      redirect(
        '/organizer',
        profile: AsyncData(testUser(role: UserRole.admin)),
      ),
      isNull,
    );
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: create event route is protected for every direct URL access.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('create event route is protected for every direct URL access', () {
    const createEvent = '/organizer/events/create';

    expect(
      redirect(
        createEvent,
        profile: AsyncData(testUser(role: UserRole.organizer)),
      ),
      isNull,
    );
    expect(
      redirect(createEvent, profile: AsyncData(testUser(role: UserRole.admin))),
      isNull,
    );
    expect(redirect(createEvent), '/home');
    expect(redirect(createEvent, auth: const AsyncData(null)), '/login');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: registration keeps form stable until action completes.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test('registration keeps form stable until action completes', () {
    expect(
      redirect('/register', profile: const AsyncData(null), busy: true),
      isNull,
    );
    expect(redirect('/register', profile: const AsyncData(null)), '/splash');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: all event management URLs fail closed for guest/student/loading/disabled.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, flutter_test, Riverpod.
  test(
    'all event management URLs fail closed for guest/student/loading/disabled',
    () {
      for (final path in [
        '/organizer',
        '/organizer/events',
        '/organizer/events/create',
        '/organizer/events/e1/edit',
        '/organizer/events/e1/participants',
      ]) {
        expect(redirect(path), '/home');
        expect(redirect(path, auth: const AsyncData(null)), '/login');
        expect(redirect(path, profile: const AsyncLoading()), '/splash');
        expect(
          redirect(
            path,
            profile: AsyncData(
              testUser(role: UserRole.organizer, status: 'disabled'),
            ),
          ),
          '/splash',
        );
        for (final role in [UserRole.organizer, UserRole.admin]) {
          expect(
            redirect(path, profile: AsyncData(testUser(role: role))),
            isNull,
          );
        }
      }
    },
  );
}

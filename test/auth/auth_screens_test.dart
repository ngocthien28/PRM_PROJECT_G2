import 'package:campushub/features/profile/data/local_profile_cache.dart';
import 'dart:async';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/screens/login_screen.dart';
import 'package:campushub/features/auth/presentation/screens/register_screen.dart';
import 'package:campushub/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:campushub/features/auth/presentation/screens/splash_screen.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_fakes.dart';

/// FEATURE: UC-014 - Test Authentication and Profile
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm void main: Form validation, loading, lỗi và reset password.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
void main() {
  late FakeProfiles profiles;
  late FakeAuth auth;
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Thiết lập/thu hồi fixture: Form validation, loading, lỗi và reset password.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Thiết lập/thu hồi fixture: Form validation, loading, lỗi và reset password.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  tearDown(() async {
    await auth.dispose();
    await profiles.dispose();
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; mount: Form validation, loading, lỗi và reset password.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profiles),
          localProfileCacheProvider.overrideWithValue(FakeLocalProfileCache()),
        ],
        child: MaterialApp(home: screen),
      ),
    );
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; fill: Form validation, loading, lỗi và reset password.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  Future<void> fill(WidgetTester tester, int index, String value) =>
      tester.enterText(find.byType(TextFormField).at(index), value);
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; submit: Form validation, loading, lỗi và reset password.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: login validates empty and malformed input without requesting Firebase.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets(
    'login validates empty and malformed input without requesting Firebase',
    (tester) async {
      await mount(tester, const LoginScreen());
      await submit(tester);
      expect(find.text('Email is required.'), findsOneWidget);
      expect(find.text('Password is required.'), findsOneWidget);
      await fill(tester, 0, 'bad');
      await fill(tester, 1, 'password');
      await submit(tester);
      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      expect(auth.calls, 0);
    },
  );
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: login disables submit and fields while loading then displays error.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets(
    'login disables submit and fields while loading then displays error',
    (tester) async {
      auth.pending = Completer<void>();
      auth.failure = const AppException('Email or password is incorrect.');
      await mount(tester, const LoginScreen());
      await fill(tester, 0, 'minh@example.com');
      await fill(tester, 1, 'password');
      await submit(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        isFalse,
      );
      auth.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(auth.calls, 1);
    },
  );
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: register enforces password policy and matching confirmation.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('register enforces password policy and matching confirmation', (
    tester,
  ) async {
    await mount(tester, const RegisterScreen());
    await fill(tester, 0, 'Minh');
    await fill(tester, 1, 'minh@example.com');
    await fill(tester, 2, 'short');
    await fill(tester, 3, 'different');
    await submit(tester);
    expect(
      find.text('Password must have at least 8 characters.'),
      findsOneWidget,
    );
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(auth.calls, 0);
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: register shows failure from repository.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('register shows failure from repository', (tester) async {
    auth.failure = const AppException(
      'This email is already registered. Please sign in.',
    );
    await mount(tester, const RegisterScreen());
    await fill(tester, 0, 'Minh');
    await fill(tester, 1, 'minh@example.com');
    await fill(tester, 2, 'password');
    await fill(tester, 3, 'password');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('This email is already registered. Please sign in.'),
      findsOneWidget,
    );
    expect(profiles.creates, 0);
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: reset has email only and validates before reporting success.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('reset has email only and validates before reporting success', (
    tester,
  ) async {
    await mount(tester, const ForgotPasswordScreen());
    expect(find.byType(TextFormField), findsOneWidget);
    await submit(tester);
    expect(find.text('Email is required.'), findsOneWidget);
    await fill(tester, 0, 'minh@example.com');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('password reset email has been sent'),
      findsOneWidget,
    );
    expect(auth.lastEmail, 'minh@example.com');
  });
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: reset shows network errors and permits retry.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('reset shows network errors and permits retry', (tester) async {
    auth.failure = const AppException('Cannot connect.');
    await mount(tester, const ForgotPasswordScreen());
    await fill(tester, 0, 'minh@example.com');
    await submit(tester);
    await tester.pumpAndSettle();
    expect(find.text('Cannot connect.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: denied profile shows recovery actions without an uncaught error.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets(
    'denied profile shows recovery actions without an uncaught error',
    (tester) async {
      auth.identity = testIdentity;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            currentUserProvider.overrideWith(
              (ref) => Stream.error(
                const AppException('Access denied.', code: 'permission-denied'),
              ),
            ),
          ],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your profile cannot be accessed'),
        findsOneWidget,
      );
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

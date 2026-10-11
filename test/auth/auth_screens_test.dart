import 'dart:async';
import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/services/firebase_providers.dart';
import 'package:campushub/features/auth/presentation/screens/login_screen.dart';
import 'package:campushub/features/auth/presentation/screens/register_screen.dart';
import 'package:campushub/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'auth_fakes.dart';

void main() {
  late FakeProfiles profiles;
  late FakeAuth auth;
  setUp(() {
    profiles = FakeProfiles();
    auth = FakeAuth(profiles);
  });
  tearDown(() async {
    await auth.dispose();
    await profiles.dispose();
  });
  Future<void> mount(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: MaterialApp(home: screen),
      ),
    );
  }

  Future<void> fill(WidgetTester tester, int index, String value) =>
      tester.enterText(find.byType(TextFormField).at(index), value);
  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

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
}

// Exercise retained-data states explicitly to verify that private data is hidden.
// ignore_for_file: invalid_use_of_internal_member

import 'package:campushub/core/errors/app_exception.dart';
import 'package:campushub/core/widgets/async_value_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// FEATURE: UC-014 - Test Authentication and Profile
/// MODULE: Testing & Integration
/// DESCRIPTION: Hàm void main: Loading/error/retry và retained profile data.
/// ROLE: Test entry point / fixture helper
/// CALLED FROM: Các test Auth/Profile/navigation.
/// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
/// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
void main() {
  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Hàm Future&lt;void&gt; show: Loading/error/retry và retained profile data.
  /// ROLE: Test entry point / fixture helper
  /// CALLED FROM: Các test Auth/Profile/navigation.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  Future<void> show(
    WidgetTester tester,
    AsyncValue<String?> value, {
    VoidCallback? retry,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AsyncValueView<String?>(
          value: value,
          onRetry: retry,
          data: (value) => Text(value ?? 'No profile'),
        ),
      ),
    ),
  );

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: loading, data and nullable data render correctly.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('loading, data and nullable data render correctly', (
    tester,
  ) async {
    await show(tester, const AsyncLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await show(tester, const AsyncData('Ready'));
    expect(find.text('Ready'), findsOneWidget);
    await show(tester, const AsyncData(null));
    expect(find.text('No profile'), findsOneWidget);
  });

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: mapped error is readable and Retry invokes recovery.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('mapped error is readable and Retry invokes recovery', (
    tester,
  ) async {
    var retries = 0;
    await show(
      tester,
      AsyncError(
        const AppException('Check your connection.'),
        StackTrace.empty,
      ),
      retry: () => retries++,
    );
    expect(find.text('Check your connection.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: unknown error hides internal details and optional Retry.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('unknown error hides internal details and optional Retry', (
    tester,
  ) async {
    await show(
      tester,
      AsyncError(StateError('private backend detail'), StackTrace.empty),
    );
    expect(find.textContaining('private backend detail'), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });

  /// FEATURE: UC-014 - Test Authentication and Profile
  /// MODULE: Testing & Integration
  /// DESCRIPTION: Kiểm thử: refresh and failure do not reveal retained profile data.
  /// ROLE: Existing test callback
  /// CALLED FROM: flutter_test runner / main.
  /// RELATED FILES: lib/features/auth/presentation/viewmodels/auth_view_model.dart; lib/features/profile/presentation/viewmodels/profile_view_model.dart.
  /// TECHNOLOGY: Dart, Flutter Material, flutter_test, Riverpod.
  testWidgets('refresh and failure do not reveal retained profile data', (
    tester,
  ) async {
    const previous = AsyncData<String?>('Previous user');
    await show(
      tester,
      const AsyncLoading<String?>().copyWithPrevious(previous),
    );
    expect(find.text('Previous user'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await show(
      tester,
      AsyncError<String?>(
        const AppException('Access denied'),
        StackTrace.empty,
      ).copyWithPrevious(previous),
    );
    expect(find.text('Previous user'), findsNothing);
    expect(find.text('Access denied'), findsOneWidget);
  });
}
